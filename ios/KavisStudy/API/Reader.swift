import CryptoKit
import Foundation
import Supabase

/// The reading page of a lesson (`material_content.reader_doc`, made by the server from the PDF; the same format as
/// the web, `web/src/api/types.ts`). The teacher's text is never changed (CLAUDE.md); only labels and explanations
/// are added.
struct ReaderDoc: Decodable {
    /// Language of the teacher's PDF; the text stays in this language.
    let language: String
    /// The server already checked the sections (Edge Function group-sections).
    let grouped: Bool?
    let sections: [ReaderSection]

    var docLang: Lang { Lang(rawValue: language) ?? .tr }

    /// The pages the reading page covers (a lesson outside any course counts its own pages).
    var pageCount: Int { Set(sections.flatMap { $0.blocks.map(\.pageFrom) }).count }
}

struct ReaderSection: Decodable {
    /// Section title as written in the PDF.
    let title: String
    let blocks: [ReaderBlock]

    var pageFrom: Int { blocks.map(\.pageFrom).min() ?? 1 }
    var pageTo: Int { blocks.map(\.pageTo).max() ?? 1 }
}

struct ReaderBlock: Decodable {
    let pageFrom: Int
    let pageTo: Int
    /// definition | dose | side_effect | special | emergency | general
    let tag: String
    let heading: String?
    let paragraphs: [Paragraph]
    let molecule: Bool?
    let audio: Bool?

    /// Label (key in the reader texts) and colour of the block kind, as on the web.
    var tagLabel: (key: String, red: Bool) {
        switch tag {
        case "dose": ("tagDose", false)
        case "side_effect": ("tagSide", true)
        case "special": ("s3tag", false)
        case "emergency": ("s4tag", true)
        case "general": ("tagGeneral", false)
        default: ("s1tag", false)
        }
    }
}

/// A paragraph is a list of segments, or one sentence the student can select.
enum Paragraph: Decodable {
    case segments([Segment])
    case selectable(String)

    private struct Selectable: Decodable { let selectable: Bool; let text: String }

    init(from decoder: Decoder) throws {
        if let s = try? decoder.singleValueContainer().decode(Selectable.self) {
            self = .selectable(s.text)
        } else {
            self = .segments(try decoder.singleValueContainer().decode([Segment].self))
        }
    }

    /// Plain text (for reading aloud and translating).
    var plain: String {
        switch self {
        case .selectable(let text): text
        case .segments(let parts): parts.map(\.text).joined()
        }
    }
}

/// Plain text, or a hard word (term key) that opens an explanation.
enum Segment: Decodable {
    case text(String)
    case term(id: String, text: String)

    private struct Term: Decodable { let term: String; let text: String }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .text(s) } else {
            let t = try c.decode(Term.self)
            self = .term(id: t.term, text: t.text)
        }
    }

    var text: String {
        switch self {
        case .text(let s): s
        case .term(_, let t): t
        }
    }
}

/// A hard word of the lesson (`material_terms`); explanation per app language.
struct ReaderTerm: Decodable {
    struct Explanation: Decodable { let name: String; let kind: String?; let text: String }
    let id: String
    let surface: String
    let page: Int?
    let explanation: [String: Explanation]
}

/// Everything the reader needs for one lesson (RLS: only the student's own rows).
struct Lesson {
    let id: String
    let title: String
    let courseId: String?
    let courseName: String
    /// nil: the reading page is not made yet (the server makes it from the PDF).
    let doc: ReaderDoc?
    /// Hard words by term key.
    let terms: [String: ReaderTerm]
    var pagesRead: [Int]
    var lastPage: Int
    var percent: Int
    let pageCount: Int
}

enum ReaderAPI {
    static func getLesson(id: String) async -> Lesson? {
        struct Course: Decodable { let name: String }
        struct Material: Decodable { let title: String; let page_count: Int?; let course_id: String?; let courses: Course? }
        struct Content: Decodable { let reader_doc: ReaderDoc? }
        struct Term: Decodable { let id: String; let term_key: String; let surface: String; let page: Int?; let explanation: [String: ReaderTerm.Explanation]? }
        struct Progress: Decodable { let pages_read: [Int]?; let last_page: Int?; let percent_read: Int? }

        async let materialQ: [Material] = supabase.from("materials").select("title, page_count, course_id, courses(name)").eq("id", value: id).limit(1).execute().value
        async let contentQ: [Content] = supabase.from("material_content").select("reader_doc").eq("material_id", value: id).limit(1).execute().value
        async let termsQ: [Term] = supabase.from("material_terms").select("id, term_key, surface, page, explanation").eq("material_id", value: id).execute().value
        async let progressQ: [Progress] = supabase.from("reading_progress").select("pages_read, last_page, percent_read").eq("material_id", value: id).limit(1).execute().value

        guard let material = (try? await materialQ)?.first else { return nil }
        let doc = await grouped(id, (try? await contentQ)?.first?.reader_doc)
        let terms = (try? await termsQ) ?? []
        let progress = (try? await progressQ)?.first
        return Lesson(
            id: id, title: material.title, courseId: material.course_id, courseName: material.courses?.name ?? "",
            doc: doc,
            terms: Dictionary(terms.map { ($0.term_key, ReaderTerm(id: $0.id, surface: $0.surface, page: $0.page, explanation: $0.explanation ?? [:])) }, uniquingKeysWith: { a, _ in a }),
            pagesRead: progress?.pages_read ?? [], lastPage: progress?.last_page ?? 1, percent: progress?.percent_read ?? 0,
            pageCount: material.page_count ?? doc?.pageCount ?? 0
        )
    }

    /// Too many small sections (about one per page) for the pages: the server groups them once into a few general
    /// parts (Edge Function group-sections). The same rule as the web and the server.
    /// The student's original PDF as a short-lived signed link (iPad "tam ekran PDF"); nil for photos or when offline.
    static func pdfURL(materialId: String) async -> URL? {
        struct File: Decodable { let storage_path: String }
        let rows: [File] = (try? await supabase.from("material_files").select("storage_path")
            .eq("material_id", value: materialId).order("sort_order").limit(1).execute().value) ?? []
        guard let path = rows.first?.storage_path, path.lowercased().hasSuffix(".pdf") else { return nil }
        return try? await supabase.storage.from("materials").createSignedURL(path: path, expiresIn: 3600)
    }

    static func needsGrouping(_ doc: ReaderDoc) -> Bool {
        guard doc.grouped != true, !doc.sections.isEmpty else { return false }
        let pages = Set(doc.sections.flatMap { $0.blocks.map(\.pageFrom) }).count
        return doc.sections.count > max(4, Int((Double(pages) / 8).rounded(.up)))
    }

    private static func grouped(_ id: String, _ doc: ReaderDoc?) async -> ReaderDoc? {
        guard let doc, needsGrouping(doc) else { return doc }
        struct Body: Encodable { let material_id: String }
        struct Done: Decodable { let grouped: Bool }
        guard let r: Done = try? await supabase.functions.invoke("group-sections", options: FunctionInvokeOptions(body: Body(material_id: id))),
              r.grouped else { return doc }
        struct Content: Decodable { let reader_doc: ReaderDoc? }
        let again: [Content]? = try? await supabase.from("material_content").select("reader_doc").eq("material_id", value: id).limit(1).execute().value
        return again?.first?.reader_doc ?? doc
    }

    /// Marks pages as read and remembers the page on screen (`at`), so the lesson opens there next time.
    static func markRead(_ lesson: Lesson, pages: Set<Int>, at: Int) async -> (pagesRead: [Int], percent: Int)? {
        guard let user = supabase.auth.currentUser else { return nil }
        let all = Array(Set(lesson.pagesRead).union(pages)).sorted()
        let percent = lesson.pageCount > 0 ? min(100, Int((Double(all.count) / Double(lesson.pageCount) * 100).rounded())) : 0
        struct Row: Encodable { let user_id, material_id: String; let pages_read: [Int]; let last_page, percent_read: Int; let finished_at: String? }
        let row = Row(user_id: user.id.uuidString.lowercased(), material_id: lesson.id, pages_read: all, last_page: at, percent_read: percent,
                      finished_at: percent == 100 ? ISO8601DateFormatter().string(from: Date()) : nil)
        do {
            try await supabase.from("reading_progress").upsert(row).execute()
        } catch {
            return nil
        }
        return (all, percent)
    }

    /// Saves a reading session (the stopwatch). Shorter than a minute is not saved.
    static func saveStudyTime(courseId: String, materialId: String, seconds: Int) async {
        guard let user = supabase.auth.currentUser, seconds >= 60 else { return }
        let ended = Date()
        let f = ISO8601DateFormatter()
        struct Row: Encodable { let user_id, course_id, material_id, activity, started_at, ended_at: String }
        _ = try? await supabase.from("study_sessions").insert(Row(
            user_id: user.id.uuidString.lowercased(), course_id: courseId, material_id: materialId, activity: "read",
            started_at: f.string(from: ended.addingTimeInterval(-Double(seconds))), ended_at: f.string(from: ended)
        )).execute()
    }

    /// Counts a tap on a hard word (for "most tapped words" in the exam center).
    static func tapTerm(_ termId: String) {
        Task { _ = try? await supabase.rpc("tap_term", params: ["p_term_id": termId]).execute() }
    }

    enum CardResult { case added, already, failed }

    /// "Kartlara ekle" on a hard word: the server (Edge Function add-card) makes the card from its explanation.
    static func addTermCard(_ termId: String) async -> CardResult {
        struct Body: Encodable { let term_id: String }
        struct Done: Decodable { let already: Bool? }
        guard let r: Done = try? await supabase.functions.invoke("add-card", options: FunctionInvokeOptions(body: Body(term_id: termId))) else { return .failed }
        return r.already == true ? .already : .added
    }

    enum TranslateFailure: Error { case locked, failed }

    /// A translation of part of the teacher's text: a saved one at once, else the server makes it with the AI and
    /// keeps it (Edge Function translate).
    static func translate(materialId: String, text: String, to lang: Lang, style: TranslationStyle) async -> Result<String, TranslateFailure> {
        let hash = SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
        struct Saved: Decodable { let text: String }
        let saved: [Saved]? = try? await supabase.from("translations").select("text")
            .eq("material_id", value: materialId).eq("source_hash", value: hash)
            .eq("target_lang", value: lang.rawValue).eq("style", value: style.rawValue).limit(1).execute().value
        if let t = saved?.first?.text { return .success(t) }
        struct Body: Encodable { let material_id, text, target_lang, style: String }
        do {
            let made: Saved = try await supabase.functions.invoke("translate", options: FunctionInvokeOptions(
                body: Body(material_id: materialId, text: text, target_lang: lang.rawValue, style: style.rawValue)))
            return .success(made.text)
        } catch FunctionsError.httpError(let code, _) {
            return .failure(code == 403 ? .locked : .failed)
        } catch {
            return .failure(.failed)
        }
    }
}
