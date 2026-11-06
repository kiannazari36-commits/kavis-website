import Foundation
import Supabase

/// Placement test after an upload ("Seviye tespiti", design/NewPlacement.dc.html), the same as the web
/// (`web/src/api/placement.ts`). The server (Edge placement-test) copies the lesson's own questions into a short
/// test: no AI, free. grade-quiz then writes each topic's state (known / weak / todo) to topic_progress.
enum PlacementAPI {
    struct Topic: Identifiable, Equatable {
        let id: String
        let title: String
        let pageFrom: Int?
        let pageTo: Int?
        /// How many multiple-choice questions of the lesson are about this topic.
        let questions: Int
    }

    struct Lesson: Equatable {
        let title: String
        let pages: Int
        let topics: [Topic]
    }

    /// A test ready to play, with each question's topic (id and title).
    struct Test: Equatable {
        let quiz: Quiz
        let topicOf: [String: String]
        let topicTitle: [String: String]
    }

    /// Same rules as the server (supabase/functions/placement-test/pick.ts).
    static let maxQuestions = 8
    static let perTopic = 2

    /// How many questions a test on these topics has.
    static func questionCount(_ topics: [Topic]) -> Int {
        min(maxQuestions, topics.reduce(0) { $0 + min(perTopic, $1.questions) })
    }

    /// The lesson's title, page count and topics in order, with how many test questions each topic has.
    static func lesson(materialId: String) async -> Lesson? {
        struct M: Decodable { let title: String; let page_count: Int? }
        struct T: Decodable { let id, title: String; let page_from, page_to: Int? }
        struct Q: Decodable { let id: String }
        struct QQ: Decodable { let topic_id: String? }
        async let mQ: [M] = supabase.from("materials").select("title, page_count").eq("id", value: materialId).limit(1).execute().value
        async let tQ: [T] = supabase.from("material_topics").select("id, title, page_from, page_to").eq("material_id", value: materialId)
            .order("sort_order").execute().value
        async let qQ: [Q] = supabase.from("quizzes").select("id").eq("material_id", value: materialId).eq("kind", value: "lesson_end")
            .limit(1).execute().value
        guard let m = (try? await mQ)?.first else { return nil }
        let topics = (try? await tQ) ?? []
        var per: [String: Int] = [:]
        if let quiz = (try? await qQ)?.first {
            let qs: [QQ] = (try? await supabase.from("quiz_questions").select("topic_id").eq("quiz_id", value: quiz.id)
                .eq("kind", value: "multiple_choice").execute().value) ?? []
            for q in qs { if let t = q.topic_id { per[t, default: 0] += 1 } }
        }
        return Lesson(title: m.title, pages: m.page_count ?? 0, topics: topics.map {
            Topic(id: $0.id, title: $0.title, pageFrom: $0.page_from, pageTo: $0.page_to, questions: per[$0.id] ?? 0)
        })
    }

    /// A test with its questions and each question's topic; nil when it is gone (a newer test replaced it).
    static func test(quizId: String) async -> Test? {
        struct Topic: Decodable { let title: String }
        struct Row: Decodable { let id: String; let topic_id: String?; let material_topics: Topic? }
        async let quizQ = QuizAPI.load(quizId: quizId)
        async let rowsQ: [Row] = supabase.from("quiz_questions").select("id, topic_id, material_topics(title)").eq("quiz_id", value: quizId).execute().value
        guard let quiz = await quizQ, !quiz.questions.isEmpty else { return nil }
        let rows = (try? await rowsQ) ?? []
        return Test(quiz: quiz,
                    topicOf: Dictionary(rows.compactMap { r in r.topic_id.map { (r.id, $0) } }, uniquingKeysWith: { a, _ in a }),
                    topicTitle: Dictionary(rows.compactMap { r in r.material_topics.map { (r.id, $0.title) } }, uniquingKeysWith: { a, _ in a }))
    }

    enum Started { case ok(Test), none, failed }

    /// Makes a new test (on some topics only, or all); `.none` when the lesson has no questions for it.
    static func start(materialId: String, topicIds: [String]?) async -> Started {
        struct Body: Encodable { let material_id: String; let topic_ids: [String]? }
        struct Res: Decodable { let quiz_id: String? }
        do {
            let r: Res = try await supabase.functions.invoke("placement-test", options: FunctionInvokeOptions(
                body: Body(material_id: materialId, topic_ids: topicIds)))
            guard let id = r.quiz_id, let test = await test(quizId: id) else { return .failed }
            return .ok(test)
        } catch FunctionsError.httpError(let code, _) {
            return code == 404 ? .none : .failed
        } catch {
            return .failed
        }
    }

    /// A test in progress, kept on this device ("Sonra devam et"). Answers: option index, or -1 = "Bilmiyorum".
    struct Saved: Codable {
        let quizId: String
        let topicIds: [String]?
        let index: Int
        let answers: [String: Int]
    }

    private static func key(_ materialId: String) -> String { "kavis.placement.\(materialId)" }

    static func saved(materialId: String) -> Saved? {
        guard let data = UserDefaults.standard.data(forKey: key(materialId)) else { return nil }
        return try? JSONDecoder().decode(Saved.self, from: data)
    }

    static func keep(materialId: String, _ test: Saved?) {
        if let test, let data = try? JSONEncoder().encode(test) {
            UserDefaults.standard.set(data, forKey: key(materialId))
        } else {
            UserDefaults.standard.removeObject(forKey: key(materialId))
        }
    }
}
