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
