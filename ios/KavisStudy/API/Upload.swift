import Foundation
import PDFKit
import Supabase
import UIKit

/// Uploading a lecture PDF, the same steps as the web (`web/src/api/upload.ts`): the file goes to the private
/// "materials" bucket (<user id>/<lesson id>/original.pdf), then the lesson row is created (the database allows it
/// only while the trial or Premium allows it), then the server prepares the reading page (Edge Function
/// process-material).
enum UploadAPI {
    /// Largest file the storage accepts (Supabase free plan: 50 MB per file).
    static let maxMB = 50.0

    enum Failure: Error { case trial, network, tooBig }

    /// How many lessons a long PDF becomes: parts of at most 100 pages.
    static func partsFor(_ pages: Int) -> Int { Int((Double(pages) / Double(TrialLimits.pagesPerPdf)).rounded(.up)) }

    /// A PDF longer than 100 pages cut into equal parts (the teacher's pages unchanged); each part is a lesson.
    static func splitPdf(_ data: Data) -> [Data] {
        guard let src = PDFDocument(data: data) else { return [] }
        let total = src.pageCount
        let k = partsFor(total)
        guard k > 1 else { return [data] }
        let size = Int((Double(total) / Double(k)).rounded(.up))
        return (0..<k).compactMap { i in pages(src, from: i * size, to: min(total, (i + 1) * size) - 1) }
    }

    /// Pages `from...to` (0-based) as a PDF of its own ("Sayfa aralığı seç").
    static func pages(_ src: PDFDocument, from: Int, to: Int) -> Data? {
        let doc = PDFDocument()
        for (j, p) in (from...to).enumerated() {
            guard let page = src.page(at: p)?.copy() as? PDFPage else { return nil }
            doc.insert(page, at: j)
        }
        return doc.dataRepresentation()
    }

    /// Uploads the file, then creates the lesson; returns the lesson id and asks the server to prepare it.
    /// The file goes first: a failed upload must not use up a trial lesson (the lesson row counts it).
    static func uploadLesson(_ data: Data, title: String, courseId: String?, ocr: Bool = false) async throws -> String {
        guard let user = supabase.auth.currentUser else { throw Failure.network }
        if Double(data.count) > maxMB * 1_048_576 { throw Failure.tooBig }
        let uid = user.id.uuidString.lowercased()
        let id = UUID().uuidString.lowercased()
        let path = "\(uid)/\(id)/original.pdf"
        let bucket = supabase.storage.from("materials")
        do {
            try await bucket.upload(path, data: data, options: FileOptions(contentType: "application/pdf", upsert: false))
        } catch {
            throw Failure.network
        }

        struct Material: Encodable { let id, user_id: String; let course_id: String?; let kind, title: String }
        do {
            try await supabase.from("materials")
                .insert(Material(id: id, user_id: uid, course_id: courseId, kind: "pdf", title: title.trimmingCharacters(in: .whitespaces)))
                .execute()
        } catch {
            // Refused (trial over or its 2 lessons used): remove the file again.
            _ = try? await bucket.remove(paths: [path])
            throw (error as? PostgrestError)?.code == "42501" ? Failure.trial : Failure.network
        }
        struct File: Encodable { let material_id, user_id, storage_path, mime_type: String; let size_bytes: Int }
        _ = try? await supabase.from("material_files")
            .insert(File(material_id: id, user_id: uid, storage_path: path, mime_type: "application/pdf", size_bytes: data.count))
            .execute()

        Task { try? await process(id, ocr: ocr) }
        return id
    }

    /// Photos of one lesson at most (each photo is one page), as on the web.
    static let maxPhotos = 30
    private static let photoSide: CGFloat = 2000

    /// A photo made ready for text recognition: upright, at most 2000 px on its long side, JPEG (same as the web).
    static func shrinkPhoto(_ image: UIImage) -> Data? {
        let scale = min(1, photoSide / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        // Drawing the image applies its orientation, so the page is upright.
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: 0.85)
    }

    /// Photos of pages (slides, notes, handwriting) as one lesson: the pages go up first, in the chosen order, then the
    /// lesson (kind "photo", it uses a trial lesson like a PDF); the server reads them with text recognition.
    static func uploadPhotos(_ photos: [Data], title: String, courseId: String?) async throws -> String {
        guard let user = supabase.auth.currentUser else { throw Failure.network }
        let uid = user.id.uuidString.lowercased()
        let id = UUID().uuidString.lowercased()
        let paths = photos.indices.map { "\(uid)/\(id)/page-\(String(format: "%03d", $0 + 1)).jpg" }
        let bucket = supabase.storage.from("materials")
        for (i, photo) in photos.enumerated() {
            do {
                try await bucket.upload(paths[i], data: photo, options: FileOptions(contentType: "image/jpeg", upsert: false))
            } catch {
                if i > 0 { _ = try? await bucket.remove(paths: Array(paths[..<i])) }
                throw Failure.network
            }
        }
        struct Material: Encodable { let id, user_id: String; let course_id: String?; let kind, title: String }
        do {
            try await supabase.from("materials")
                .insert(Material(id: id, user_id: uid, course_id: courseId, kind: "photo", title: title.trimmingCharacters(in: .whitespaces)))
                .execute()
        } catch {
            _ = try? await bucket.remove(paths: paths)
            throw (error as? PostgrestError)?.code == "42501" ? Failure.trial : Failure.network
        }
        struct File: Encodable { let material_id, user_id, storage_path, mime_type: String; let size_bytes, sort_order: Int }
        _ = try? await supabase.from("material_files")
            .insert(photos.enumerated().map { File(material_id: id, user_id: uid, storage_path: paths[$0.offset], mime_type: "image/jpeg", size_bytes: $0.element.count, sort_order: $0.offset) })
            .execute()
        Task { try? await process(id) }
        return id
    }

    private struct ProcessBody: Encodable { let material_id: String; let ocr: Bool? }

    private static func process(_ id: String, ocr: Bool? = nil) async throws {
        try await supabase.functions.invoke("process-material", options: FunctionInvokeOptions(body: ProcessBody(material_id: id, ocr: ocr)))
    }

    /// "Metin tanıma ile dene" for a lesson the server found scanned.
    static func retryWithOcr(_ id: String) async -> Result<Void, Failure> {
        do {
            try await process(id, ocr: true)
            return .success(())
        } catch FunctionsError.httpError(let code, _) {
            return .failure(code == 403 ? .trial : .network)
        } catch {
            return .failure(.network)
        }
    }

    enum Status: String, Decodable { case uploaded, processing, ready, needs_ocr, too_long, failed }

    struct LessonStatus {
        let status: Status
        let pages: Int?
        let courseId: String?
        let stats: [String: Int]
        /// Last change on the server (a "processing" lesson unchanged for long was stopped).
        let updatedAt: Date?
    }

    /// Where the server is with a lesson (the processing screen asks every 4 seconds).
    static func lessonStatus(_ id: String) async -> LessonStatus? {
        struct Content: Decodable { let stats: [String: Int]? }
        struct Row: Decodable {
            let status: Status
            let page_count: Int?
            let course_id: String?
            let updated_at: Date?
            let material_content: OneOrMany<Content>?
        }
        guard let r: Row = try? await supabase.from("materials")
            .select("status, page_count, course_id, updated_at, material_content(stats)")
            .eq("id", value: id).single().execute().value else { return nil }
        return LessonStatus(status: r.status, pages: r.page_count, courseId: r.course_id, stats: r.material_content?.first?.stats ?? [:], updatedAt: r.updated_at)
    }

    /// Lessons whose preparation was stopped on the server (still "processing" after 5 minutes): asking again makes
    /// it go on from the last finished part. Called when the app opens and while a lesson is being prepared.
    static func resumeStuckLessons() async {
        struct Row: Decodable { let id: String }
        let since = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-5 * 60))
        guard let rows: [Row] = try? await supabase.from("materials").select("id")
            .eq("status", value: "processing").lt("updated_at", value: since).execute().value else { return }
        for r in rows { Task { try? await process(r.id) } }
    }
}

/// An embedded row that PostgREST sends as one object or as a list (one-to-one relations).
struct OneOrMany<T: Decodable>: Decodable {
    let items: [T]
    var first: T? { items.first }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let list = try? c.decode([T].self) { items = list } else { items = [try c.decode(T.self)] }
    }
}
