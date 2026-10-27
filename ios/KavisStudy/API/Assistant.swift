import Supabase
import UIKit

/// A course (or "all my courses") the assistant can answer about: the student's own courses, like the web.
struct AssistantTopic: Identifiable, Hashable {
    let id: String
    /// nil for "all my courses".
    let courseId: String?
    let name: L10n
    /// The first lessons of the course.
    let sub: L10n
    /// Dot color as "#RRGGBB".
    let color: String

    var isAll: Bool { id == "all" }
}

enum AttachmentKind: String, CaseIterable { case pdf, photo, audio }

/// "Only my PDFs" or "AI + research" (the server may then also search the web).
enum SourceMode: String, Codable { case pdf, ai }

/// One message of a conversation, as the server saves it (`assistant_messages`).
struct ChatMessage: Identifiable, Equatable {
    enum Role: String { case user, assistant }
    struct Source: Equatable { let lesson: String; let page: Int? }
    struct Link: Equatable { let url: String; let title: String }
    /// What the assistant did when asked: a topic added to the weak topics, or a flash card made.
    struct Act: Equatable { let kind: String; let title: String }

    var id = UUID().uuidString
    let role: Role
    var text: String
    var sources: [Source] = []
    var links: [Link] = []
    var acts: [Act] = []
    var outsidePdf = false
    /// The question photo of "Soruyu çözdür" (only on this phone; the server keeps the text).
    var photo: Data? = nil
}

/// A past conversation ("Geçmiş"), newest first.
struct ChatThread: Identifiable, Equatable {
    let id: String
    let courseId: String?
    let title: String
    let updatedAt: Date?
}

enum AssistantAPI {
    /// Main colours of the course folders (the dots on the course cards).
    private static let colors: [CourseColor: String] = [.red: "#9C2F3A", .amb: "#A86F0E", .vio: "#4A3F9A", .grn: "#2E7D4F", .teal: "#1F6E75"]

    private static func same(_ s: String) -> L10n { L10n(tr: s, en: s, fa: s, ar: s) }

    /// The student's courses with their first lessons, then "all my courses".
    static func listTopics() async -> [AssistantTopic] {
        let courses = await CoursesAPI.listCourses()
        return courses.map { c in
            AssistantTopic(id: c.id, courseId: c.id, name: c.short ?? c.name,
                           sub: same(c.pdfs.prefix(2).map { $0.title.tr }.joined(separator: " · ")), color: colors[c.color] ?? "#9C2F3A")
        } + [AssistantTopic(id: "all", courseId: nil, name: L10n(tr: Strings.design("Tüm derslerim", .tr), en: Strings.design("Tüm derslerim", .en), fa: Strings.design("Tüm derslerim", .fa), ar: Strings.design("Tüm derslerim", .ar)),
                            sub: same(""), color: "#F2B33D")]
    }

    /// The latest conversation about a course (or all courses), oldest message first. Written by the server.
    static func latestThread(courseId: String?) async -> (id: String?, messages: [ChatMessage]) {
        struct Thread: Decodable { let id: String }
        var q = supabase.from("assistant_threads").select("id")
        q = courseId.map { q.eq("course_id", value: $0) } ?? q.is("course_id", value: nil)
        guard let thread = (try? await q.order("updated_at", ascending: false).limit(1).execute().value as [Thread])?.first else { return (nil, []) }
        return (thread.id, await messages(threadId: thread.id))
    }

    /// The messages of one conversation, oldest first.
    static func messages(threadId: String) async -> [ChatMessage] {
        struct Src: Decodable { let material_id: String?; let page: Int?; let url: String?; let title: String?; let act: String? }
        struct Row: Decodable { let role: String; let content: String; let sources: [Src]?; let outside_pdf: Bool? }
        let rows: [Row] = (try? await supabase.from("assistant_messages").select("role, content, sources, outside_pdf")
            .eq("thread_id", value: threadId).order("created_at").execute().value) ?? []
        if CoursesAPI.lastCourses.isEmpty { _ = await CoursesAPI.listCourses() }
        let lessons = Dictionary(CoursesAPI.lastCourses.flatMap { c in c.pdfs.map { ($0.id, $0.title.tr) } }, uniquingKeysWith: { a, _ in a })
        return rows.map { r in
            let s = r.sources ?? []
            return ChatMessage(role: ChatMessage.Role(rawValue: r.role) ?? .assistant, text: r.role == "assistant" ? visible(r.content) : r.content,
                               sources: s.compactMap { x in x.material_id.map { ChatMessage.Source(lesson: lessons[$0] ?? "", page: x.page) } },
                               links: s.compactMap { x in x.url.map { ChatMessage.Link(url: $0, title: x.title ?? $0) } },
                               acts: s.compactMap { x in x.act.map { ChatMessage.Act(kind: $0, title: x.title ?? "") } },
                               outsidePdf: r.outside_pdf ?? false)
        }
    }

    /// The student's conversations, newest first ("Geçmiş" on the assistant's start screen).
    static func threads() async -> [ChatThread] {
        struct Row: Decodable { let id: String; let course_id: String?; let title: String?; let updated_at: String }
        let rows: [Row] = (try? await supabase.from("assistant_threads").select("id, course_id, title, updated_at")
            .order("updated_at", ascending: false).limit(50).execute().value) ?? []
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        return rows.map { ChatThread(id: $0.id, courseId: $0.course_id, title: $0.title ?? "", updatedAt: f.date(from: $0.updated_at) ?? plain.date(from: $0.updated_at)) }
    }

    /// A photo for "Soruyu çözdür": upright JPEG, longest side 1600 px (same as the web).
    static func photoForAssistant(_ image: UIImage) -> Data? {
        let scale = min(1, 1600 / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: 0.85)
    }

    /// "Soru fotoğrafı": the photo of a lecturer's question becomes one of the course's question samples
    /// (`question_samples` + the private "question-samples" bucket, same as the web's "Soru örneklerim").
    static func addQuestionSample(_ jpeg: Data, courseId: String, title: String) async -> Bool {
        guard let user = supabase.auth.currentUser else { return false }
        let uid = user.id.uuidString.lowercased()
        let path = "\(uid)/\(courseId)/\(UUID().uuidString.lowercased()).jpg"
        let bucket = supabase.storage.from("question-samples")
        do {
            try await bucket.upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg"))
        } catch {
            return false
        }
        struct Row: Encodable { let user_id, course_id, kind, title, storage_path: String }
        do {
            try await supabase.from("question_samples").insert(Row(user_id: uid, course_id: courseId, kind: "photo", title: title, storage_path: path)).execute()
            return true
        } catch {
            _ = try? await bucket.remove(paths: [path])
            return false
        }
    }

    enum AskError: Error { case locked, budget, declined, other }

    /// The answer while it is written: the closing "SOURCES: …" line is the server's, not for the student; no ** bold.
    static func visible(_ text: String) -> String {
        var t = text
        if let at = t.range(of: "SOURCES:") {
            t = String(t[..<at.lowerBound])
        } else if let tail = t.range(of: #"\n?S(O(U(R(C(E(S)?)?)?)?)?)?$"#, options: .regularExpression) {
            t.removeSubrange(tail)
        }
        // "[E1]" are the server's excerpt numbers, not for the student (the sources show the pages).
        t = t.replacingOccurrences(of: #" ?\[E\d+(, ?E\d+)*\]"#, with: "", options: .regularExpression)
        return t.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Asks the assistant (Edge Function "assistant", the same as the web): it searches the student's lessons,
    /// answers only from them (or also from general knowledge and the web in "AI + research"), saves the chat and
    /// counts the trial question. The answer arrives piece by piece (`onText` gets the text so far).
    static func ask(_ question: String, courseId: String?, threadId: String?, mode: SourceMode, lang: Lang, photo: Data? = nil,
                    onText: @escaping @MainActor (String) -> Void) async -> Result<(threadId: String, message: ChatMessage), AskError> {
        guard let token = try? await supabase.auth.session.accessToken else { return .failure(.other) }
        var req = URLRequest(url: Config.supabaseURL.appendingPathComponent("functions/v1/assistant"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Config.supabaseKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: Any?] = ["question": question, "course_id": courseId, "material_id": nil, "thread_id": threadId,
                                    "mode": mode.rawValue, "lang": lang.rawValue, "page_from": nil, "page_to": nil,
                                    "image": photo.map { ["media_type": "image/jpeg", "data": $0.base64EncodedString()] }]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body.mapValues { $0 ?? NSNull() })

        struct Event: Decodable {
            struct Src: Decodable { let lesson: String; let page: Int? }
            struct Link: Decodable { let url: String; let title: String }
            struct Act: Decodable { let kind: String; let title: String }
            let t: String?; let done: Bool?; let error: String?; let thread_id: String?; let answer: String?
            let sources: [Src]?; let links: [Link]?; let acts: [Act]?; let outside_pdf: Bool?
        }
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else { return .failure(status == 403 ? .locked : status == 429 ? .budget : .other) }
            var text = ""
            // Server-sent events: one "data: {json}" line per event.
            for try await line in bytes.lines where line.hasPrefix("data: ") {
                guard let e = try? JSONDecoder().decode(Event.self, from: Data(line.dropFirst(6).utf8)) else { continue }
                if let t = e.t {
                    text += t
                    let soFar = visible(text)
                    await onText(soFar)
                } else if let err = e.error {
                    return .failure(err == "declined" ? .declined : .other)
                } else if e.done == true, let id = e.thread_id {
                    return .success((id, ChatMessage(
                        role: .assistant, text: visible(e.answer ?? text),
                        sources: (e.sources ?? []).map { .init(lesson: $0.lesson, page: $0.page) },
                        links: (e.links ?? []).map { .init(url: $0.url, title: $0.title) },
                        acts: (e.acts ?? []).map { .init(kind: $0.kind, title: $0.title) },
                        outsidePdf: e.outside_pdf ?? false)))
                }
            }
            return .failure(.other)
        } catch {
            return .failure(.other)
        }
    }
}
