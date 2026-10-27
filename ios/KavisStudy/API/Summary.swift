import Foundation
import Supabase

/// "Ders özeti" (design ScrReview, tab "Bu ders"), the same as the web (`web/src/api/summary.ts`): one lesson's weak
/// topics (from quiz results and "bu konuda zayıfım"), the hard words the student tapped, and a short review summary
/// from the PDF (Edge Function lesson-summary: made once, kept, remade when the weak list changes).
struct LessonSummary: Equatable {
    struct Weak: Identifiable, Equatable { let id: String; let title: String; let page: Int?; let mastery: Int; let sure: Bool }
    struct Word: Equatable { let word: String; let text: String; let taps: Int }
    var title = ""
    var pages: Int?
    var weak: [Weak] = []
    var words: [Word] = []
    var score: Int?
    var scoredOn: Date?
}

struct RecapPoint: Decodable, Equatable {
    let text: String
    let page_from: Int
    let page_to: Int
    /// About one of the student's weak topics (shown with the "Zayıf konun" mark).
    let weak: Bool?
}

enum RecapFailure: Error { case locked, budget, failed }

enum SummaryAPI {
    static func lessonData(materialId: String, lang: Lang) async -> LessonSummary {
        struct Material: Decodable { let title: String; let page_count: Int? }
        struct Progress: Decodable { let state: String; let mastery: Double? }
        struct Topic: Decodable {
            let id, title: String
            let page_from: Int?
            let progress: [Progress]
            enum CodingKeys: String, CodingKey { case id, title, page_from, topic_progress }
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                id = try c.decode(String.self, forKey: .id)
                title = try c.decode(String.self, forKey: .title)
                page_from = try c.decodeIfPresent(Int.self, forKey: .page_from)
                // One row per student: PostgREST sends an object or a list.
                if let list = try? c.decode([Progress].self, forKey: .topic_progress) { progress = list }
                else { progress = (try? c.decode(Progress.self, forKey: .topic_progress)).map { [$0] } ?? [] }
            }
        }
        struct Term: Decodable { let surface: String; let explanation: [String: ReaderTerm.Explanation]? }
        struct Tap: Decodable { let taps: Int; let material_terms: Term }
        struct QTopic: Decodable { let topic_id: String? }
        struct Sure: Decodable { let quiz_questions: QTopic? }
        struct Attempt: Decodable { let score: Double?; let started_at: Date }

        async let materialQ: [Material] = supabase.from("materials").select("title, page_count").eq("id", value: materialId).limit(1).execute().value
        async let topicsQ: [Topic] = supabase.from("material_topics").select("id, title, page_from, topic_progress(state, mastery)")
            .eq("material_id", value: materialId).order("sort_order").execute().value
        async let tapsQ: [Tap] = supabase.from("term_lookups").select("taps, material_terms!inner(surface, explanation, material_id)")
            .eq("material_terms.material_id", value: materialId).order("taps", ascending: false).limit(6).execute().value
        async let sureQ: [Sure] = supabase.from("quiz_answers").select("quiz_questions(topic_id)")
            .eq("correct", value: false).eq("confidence", value: "sure").execute().value
        async let attemptQ: [Attempt] = supabase.from("quiz_attempts").select("score, started_at, quizzes!inner(material_id)")
            .eq("quizzes.material_id", value: materialId).not("score", operator: .is, value: "null")
            .order("started_at", ascending: false).limit(1).execute().value

        var s = LessonSummary()
        if let m = (try? await materialQ)?.first { s.title = m.title; s.pages = m.page_count }
        let sureTopics = Set(((try? await sureQ) ?? []).compactMap { $0.quiz_questions?.topic_id })
        s.weak = ((try? await topicsQ) ?? []).compactMap { t -> LessonSummary.Weak? in
            let p = t.progress.first
            let mastery = Int((p?.mastery ?? 100).rounded())
            guard p?.state == "weak" || mastery < 60 else { return nil }
            return .init(id: t.id, title: t.title, page: t.page_from, mastery: mastery, sure: sureTopics.contains(t.id))
        }.sorted { $0.mastery < $1.mastery }
        s.words = ((try? await tapsQ) ?? []).map { w in
            let ex = w.material_terms.explanation
            let e = ex?[lang.rawValue] ?? ex?["tr"] ?? ex?.values.first
            return .init(word: w.material_terms.surface, text: e?.text ?? "", taps: w.taps)
        }
        if let last = (try? await attemptQ)?.first {
            s.score = last.score.map { Int($0.rounded()) }
            s.scoredOn = last.started_at
        }
        return s
    }

    /// The short review summary: a saved one at once, else the server makes it with the AI (once per lesson).
    static func recap(materialId: String) async -> Result<(points: [RecapPoint], lang: Lang), RecapFailure> {
        struct Body: Encodable { let material_id: String }
        struct Made: Decodable { let points: [RecapPoint]; let lang: String? }
        do {
            let made: Made = try await supabase.functions.invoke("lesson-summary", options: FunctionInvokeOptions(body: Body(material_id: materialId)))
            return .success((made.points, Lang(rawValue: made.lang ?? "") ?? .tr))
        } catch FunctionsError.httpError(let code, _) {
            return .failure(code == 403 ? .locked : code == 429 ? .budget : .failed)
        } catch {
            return .failure(.failed)
        }
    }
}

/// "Genel özet" (design ScrReview, tab "Genel özet"): the state of every course, the 5 weakest topics over all courses
/// and the most tapped words, from the student's own rows (topic_progress, term_lookups).
struct GeneralSummary: Equatable {
    struct CourseState: Identifiable, Equatable {
        let id: String
        let name: String
        /// Average mastery of the course's measured topics, nil while nothing is measured.
        let mastery: Int?
        let pdfs: Int
        let weakTopics: Int
    }
    struct Weak: Identifiable, Equatable { let id: String; let title: String; let course: String; let page: Int?; let materialId: String; let mastery: Int }
    var courses: [CourseState] = []
    var weak: [Weak] = []
    var words: [(word: String, taps: Int)] = []
    var pdfs: Int { courses.reduce(0) { $0 + $1.pdfs } }

    static func == (a: GeneralSummary, b: GeneralSummary) -> Bool {
        a.courses == b.courses && a.weak == b.weak && a.words.map(\.word) == b.words.map(\.word)
    }
}

extension SummaryAPI {
    static func generalData() async -> GeneralSummary {
        struct Progress: Decodable { let state: String; let mastery: Double? }
        struct Material: Decodable { let course_id: String }
        struct Topic: Decodable {
            let id, title, material_id: String
            let page_from: Int?
            let progress: [Progress]
            let materials: Material?
            enum CodingKeys: String, CodingKey { case id, title, material_id, page_from, materials, topic_progress }
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                id = try c.decode(String.self, forKey: .id)
                title = try c.decode(String.self, forKey: .title)
                material_id = try c.decode(String.self, forKey: .material_id)
                page_from = try c.decodeIfPresent(Int.self, forKey: .page_from)
                materials = try? c.decodeIfPresent(Material.self, forKey: .materials)
                // One row per student: PostgREST sends an object or a list.
                if let list = try? c.decode([Progress].self, forKey: .topic_progress) { progress = list }
                else { progress = (try? c.decode(Progress.self, forKey: .topic_progress)).map { [$0] } ?? [] }
            }
        }
        struct Term: Decodable { let surface: String }
        struct Tap: Decodable { let taps: Int; let material_terms: Term? }

        async let topicsQ: [Topic] = supabase.from("material_topics")
            .select("id, title, material_id, page_from, materials!inner(course_id), topic_progress(state, mastery)").execute().value
        async let tapsQ: [Tap] = supabase.from("term_lookups").select("taps, material_terms(surface)").order("taps", ascending: false).limit(40).execute().value
        async let coursesQ = CoursesAPI.listCourses()

        let courses = await coursesQ
        let names = Dictionary(uniqueKeysWithValues: courses.map { ($0.id, $0.name.tr) })
        var g = GeneralSummary()
        // Only topics with a result count (a quiz, or marked weak / known).
        struct Measured { let topic: Topic; let courseId: String; let mastery: Int; let weak: Bool }
        let measured: [Measured] = ((try? await topicsQ) ?? []).compactMap { t in
            guard let p = t.progress.first, let cid = t.materials?.course_id else { return nil }
            guard let m = p.mastery else { return p.state == "weak" ? Measured(topic: t, courseId: cid, mastery: 0, weak: true) : nil }
            let mastery = Int(m.rounded())
            return Measured(topic: t, courseId: cid, mastery: mastery, weak: p.state == "weak" || mastery < 60)
        }
        g.courses = courses.map { c in
            let own = measured.filter { $0.courseId == c.id }
            let avg = own.isEmpty ? nil : Int((Double(own.reduce(0) { $0 + $1.mastery }) / Double(own.count)).rounded())
            return .init(id: c.id, name: c.name.tr, mastery: avg, pdfs: c.pdfs.count, weakTopics: own.filter(\.weak).count)
        }
        g.weak = measured.filter(\.weak).sorted { $0.mastery < $1.mastery }.prefix(5).map {
            .init(id: $0.topic.id, title: $0.topic.title, course: names[$0.courseId] ?? "", page: $0.topic.page_from,
                  materialId: $0.topic.material_id, mastery: $0.mastery)
        }
        var words: [String: Int] = [:]
        for t in (try? await tapsQ) ?? [] { if let w = t.material_terms?.surface { words[w, default: 0] += t.taps } }
        g.words = words.sorted { $0.value > $1.value }.prefix(8).map { ($0.key, $0.value) }
        return g
    }
}
