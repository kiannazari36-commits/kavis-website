import Foundation
import Supabase

/// Lecture recordings, the same steps as the web (`web/src/api/recording.ts`): the phone turns the sound into text
/// (Transcriber, on the device); only the text goes to the server (Edge Function process-recording), which matches it
/// to the PDF lesson's pages and finds what the lecturer stressed. The sound file is kept in the student's private
/// folder when it fits (50 MB), for listening. Recordings do not use a trial lesson.
enum RecordingAPI {
    /// One timestamped line of the talk (seconds from the start), as process-recording expects it.
    struct Segment: Codable, Equatable {
        let start: Double
        let end: Double
        let text: String
    }

    /// A ready lesson (PDF or photos) a recording can belong to.
    struct LessonPick: Identifiable, Equatable {
        let id: String
        let title: String
        let courseId: String?
        let courseName: String
        /// The lesson's language ("tr", "en", …), which the speech recognition listens for.
        let language: String?
    }

    enum Failure: Error { case network }

    /// Ready lessons a recording can belong to, newest first.
    static func lessonsForRecording() async -> [LessonPick] {
        struct CourseName: Decodable { let name: String }
        struct Row: Decodable {
            let id: String
            let title: String
            let course_id: String?
            let language: String?
            let courses: CourseName?
        }
        let rows: [Row] = (try? await supabase.from("materials")
            .select("id, title, course_id, language, courses(name)")
            .in("kind", values: ["pdf", "photo"])
            .eq("status", value: "ready")
            .order("created_at", ascending: false)
            .execute().value) ?? []
        return rows.map { LessonPick(id: $0.id, title: $0.title, courseId: $0.course_id, courseName: $0.courses?.name ?? "", language: $0.language) }
    }

    /// Sound types the storage accepts (supabase migration: bucket "materials"), by file extension.
    static func mimeType(_ ext: String) -> String? {
        switch ext.lowercased() {
        case "m4a", "mp4": "audio/mp4"
        case "mp3": "audio/mpeg"
        case "wav": "audio/wav"
        case "aac": "audio/aac"
        default: nil
        }
    }

    /// Saves the recording: the sound (when it fits) and the recording lesson, then sends the text to the server.
    /// Returns the recording's id.
    static func addRecording(sound: URL?, lesson: LessonPick, title: String, segments: [Segment], seconds: Int) async throws -> String {
        guard let user = supabase.auth.currentUser else { throw Failure.network }
        let uid = user.id.uuidString.lowercased()
        let id = UUID().uuidString.lowercased()
        let ext = sound?.pathExtension.lowercased() ?? ""
        let type = mimeType(ext)
        let data = sound.flatMap { try? Data(contentsOf: $0) }
        let keep = type != nil && data != nil && Double(data!.count) <= UploadAPI.maxMB * 1_048_576
        let path = "\(uid)/\(id)/recording.\(type == "audio/mpeg" ? "mp3" : type == "audio/wav" ? "wav" : type == "audio/aac" ? "aac" : "m4a")"
        let bucket = supabase.storage.from("materials")
        if keep, let data, let type {
            do {
                try await bucket.upload(path, data: data, options: FileOptions(contentType: type, upsert: false))
            } catch {
                throw Failure.network
            }
        }
        struct Material: Encodable { let id, user_id: String; let course_id: String?; let linked_material_id, kind, title: String }
        do {
            try await supabase.from("materials")
                .insert(Material(id: id, user_id: uid, course_id: lesson.courseId, linked_material_id: lesson.id, kind: "audio", title: title.trimmingCharacters(in: .whitespaces)))
                .execute()
        } catch {
            if keep { _ = try? await bucket.remove(paths: [path]) }
            throw Failure.network
        }
        if keep, let data, let type {
            struct File: Encodable { let material_id, user_id, storage_path, mime_type: String; let size_bytes: Int }
            _ = try? await supabase.from("material_files")
                .insert(File(material_id: id, user_id: uid, storage_path: path, mime_type: type, size_bytes: data.count))
                .execute()
        }
        struct Body: Encodable { let material_id: String; let segments: [Segment]; let duration: Int }
        Task { try? await supabase.functions.invoke("process-recording", options: FunctionInvokeOptions(body: Body(material_id: id, segments: segments, duration: seconds))) }
        return id
    }
}
