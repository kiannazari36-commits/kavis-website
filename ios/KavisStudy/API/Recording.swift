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

    // MARK: The recording page (web `getRecording`)

    struct Part: Decodable { let start, end: Double; let page: Int; let topic_id: String? }
    struct Topic: Decodable, Identifiable { let topic_id: String; let title: String; let minutes: Double; let repeats: Int; let said_exam: Bool; var id: String { topic_id } }
    struct Quote: Decodable { let at: Double; let kind: String; let text: String; let topic_id: String? }

    /// A recording with what the server found: the talk's lines, the PDF page of each part, time per topic and the
    /// moments the lecturer stressed ("sınavda çıkar").
    struct Recording {
        let id: String
        let title: String
        let status: String
        let seconds: Int
        let pdf: (id: String, title: String, courseId: String?, language: String?)?
        /// Signed link to the sound for 1 hour, or nil when only the text was kept.
        let audioURL: URL?
        let segments: [Segment]
        let parts: [Part]
        /// Most minutes first.
        let topics: [Topic]
        let quotes: [Quote]

        var working: Bool { status == "processing" || status == "uploaded" }

        /// The PDF page the talk was about at `sec` (0 = none).
        func page(at sec: Double) -> Int { parts.first { sec >= $0.start && sec < $0.end }?.page ?? 0 }
    }

    static func getRecording(_ id: String) async -> Recording? {
        struct File: Decodable { let storage_path: String }
        struct Row: Decodable { let id, title, status: String; let duration_sec: Int?; let linked_material_id: String?; let material_files: [File]? }
        struct Lecture: Decodable { let segments: [Segment]?; let parts: [Part]?; let topics: [Topic]?; let quotes: [Quote]? }
        struct Content: Decodable { let lecture: Lecture? }
        struct Pdf: Decodable { let id, title: String; let course_id, language: String? }
        async let rowQ: [Row] = supabase.from("materials").select("id, title, status, duration_sec, linked_material_id, material_files(storage_path)")
            .eq("id", value: id).limit(1).execute().value
        async let contentQ: [Content] = supabase.from("material_content").select("lecture").eq("material_id", value: id).limit(1).execute().value
        guard let m = (try? await rowQ)?.first else { return nil }
        let lecture = (try? await contentQ)?.first?.lecture
        var link: URL?
        if let path = m.material_files?.first?.storage_path {
            link = try? await supabase.storage.from("materials").createSignedURL(path: path, expiresIn: 3600)
        }
        var pdf: Pdf?
        if let linked = m.linked_material_id {
            pdf = (try? await supabase.from("materials").select("id, title, course_id, language").eq("id", value: linked).limit(1).execute().value as [Pdf])?.first
        }
        return Recording(
            id: m.id, title: m.title, status: m.status, seconds: m.duration_sec ?? 0,
            pdf: pdf.map { ($0.id, $0.title, $0.course_id, $0.language) }, audioURL: link,
            segments: lecture?.segments ?? [], parts: lecture?.parts ?? [],
            topics: (lecture?.topics ?? []).sorted { $0.minutes > $1.minutes }, quotes: lecture?.quotes ?? [])
    }

    /// One recording in a list (course folder, reader).
    struct Item: Identifiable, Decodable {
        let id: String
        let title: String
        let status: String
        let duration_sec: Int?
        let created_at: String?
        var seconds: Int { duration_sec ?? 0 }
        var day: String { String((created_at ?? "").prefix(10)) }
    }

    /// A course's recordings, newest first (course folder list).
    static func recordingsOfCourse(_ courseId: String) async -> [Item] {
        (try? await supabase.from("materials").select("id, title, status, duration_sec, created_at")
            .eq("kind", value: "audio").eq("course_id", value: courseId)
            .order("created_at", ascending: false).execute().value) ?? []
    }

    /// Recordings made for a lesson, newest first (the reader's "Ses kaydı" button).
    static func recordingsOf(_ pdfId: String) async -> [Item] {
        (try? await supabase.from("materials").select("id, title, status, duration_sec, created_at")
            .eq("kind", value: "audio").eq("linked_material_id", value: pdfId)
            .order("created_at", ascending: false).execute().value) ?? []
    }

    /// A note on a PDF page from the lecture recording: what the lecturer said there and where in the recording
    /// (the web's `LectureMark`).
    struct LectureMark: Identifiable {
        let page: Int
        let recordingId: String
        let at: Double
        /// exam | stress | time
        let kind: String
        let text: String
        let minutes: Int
        var id: String { "\(recordingId)-\(kind)-\(page)-\(Int(at))" }
    }

    /// Notes for the reading page from the lesson's recordings: "sınavda çıkar" / stressed moments on the page they were
    /// said about (the part of the talk that matches the page, else the topic's first page), and pages the lecturer
    /// spent 2 minutes or more on.
    static func lectureMarks(_ pdfId: String) async -> [LectureMark] {
        struct Topic: Decodable { let id: String; let page_from: Int? }
        struct Lecture: Decodable { let parts: [Part]?; let quotes: [Quote]? }
        struct Row: Decodable { let material_id: String; let lecture: Lecture? }
        let recs = await recordingsOf(pdfId).filter { $0.status == "ready" }
        guard !recs.isEmpty else { return [] }
        async let topicsQ: [Topic] = supabase.from("material_topics").select("id, page_from").eq("material_id", value: pdfId).execute().value
        async let rowsQ: [Row] = supabase.from("material_content").select("material_id, lecture").in("material_id", values: recs.map(\.id)).execute().value
        let topicPage = Dictionary(uniqueKeysWithValues: ((try? await topicsQ) ?? []).map { ($0.id, $0.page_from ?? 0) })
        var marks: [LectureMark] = []
        for r in (try? await rowsQ) ?? [] {
            let parts = r.lecture?.parts ?? []
            for q in r.lecture?.quotes ?? [] {
                let part = parts.first { q.at >= $0.start && q.at < $0.end && $0.page > 0 }
                let page = part?.page ?? q.topic_id.flatMap { topicPage[$0] } ?? 0
                if page > 0 { marks.append(LectureMark(page: page, recordingId: r.material_id, at: q.at, kind: q.kind, text: q.text, minutes: 0)) }
            }
            var perPage: [Int: (seconds: Double, at: Double)] = [:]
            for p in parts where p.page > 0 {
                let x = perPage[p.page] ?? (0, p.start)
                perPage[p.page] = (x.seconds + (p.end - p.start), min(x.at, p.start))
            }
            for (page, x) in perPage where x.seconds >= 120 {
                marks.append(LectureMark(page: page, recordingId: r.material_id, at: x.at, kind: "time", text: "", minutes: Int((x.seconds / 60).rounded())))
            }
        }
        return marks
    }
}
