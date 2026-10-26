import Foundation
import Supabase

/// A question of a quiz the server made from the lesson (`quiz_questions`), in the lecturer's style.
struct QuizQuestion: Identifiable, Equatable {
    let id: String
    let text: String
    let options: [String]
    /// Index of the right option.
    let answer: Int
    let why: String
    let page: Int?
    let hints: [String]
    /// The lesson the question is from, when the quiz mixes lessons (exam center).
    var materialId: String? = nil
}

/// A quiz ready to play: its questions in the language of the lesson (the content language).
struct Quiz: Equatable {
    let id: String
    let lang: Lang
    let questions: [QuizQuestion]
}

enum Confidence: String { case sure, unsure, guess }

/// Quizzes, the same as the web (`web/src/api/quiz.ts`). Scores are written only by the server (grade-quiz).
enum QuizAPI {
    /// The newest quiz of a kind for one lesson, with its questions in order.
    static func latest(kind: String, materialId: String) async -> Quiz? {
        struct Row: Decodable { let id: String; let lang: String? }
        guard let quiz = (try? await supabase.from("quizzes").select("id, lang").eq("kind", value: kind).eq("material_id", value: materialId)
            .order("created_at", ascending: false).limit(1).execute().value as [Row])?.first else { return nil }
        struct Q: Decodable {
            let id, text: String
            let options: [String]?
            let answer_index: Int?
            let explanation: String?
            let source_page: Int?
            let hints: [String]?
        }
        let rows: [Q] = (try? await supabase.from("quiz_questions").select("id, text, options, answer_index, explanation, source_page, hints")
            .eq("quiz_id", value: quiz.id).order("sort_order").execute().value) ?? []
        return Quiz(id: quiz.id, lang: Lang(rawValue: quiz.lang ?? "") ?? .tr, questions: rows.compactMap {
            guard let options = $0.options, options.count > 1 else { return nil } // the phone plays multiple choice
            return QuizQuestion(id: $0.id, text: $0.text, options: options, answer: $0.answer_index ?? 0, why: $0.explanation ?? "",
                                page: $0.source_page, hints: $0.hints ?? [])
        })
    }

    /// A quiz by its id (an exam from the exam center): its questions, each with the lesson it came from.
    static func load(quizId: String) async -> Quiz? {
        struct Options: Decodable { let sources: [String: String?]? }
        struct Row: Decodable { let id: String; let lang: String?; let options: Options? }
        guard let quiz = (try? await supabase.from("quizzes").select("id, lang, options").eq("id", value: quizId).limit(1).execute().value as [Row])?.first
        else { return nil }
        struct Q: Decodable {
            let id, text: String
            let options: [String]?
            let answer_index: Int?
            let explanation: String?
            let source_page: Int?
            let hints: [String]?
        }
        let rows: [Q] = (try? await supabase.from("quiz_questions").select("id, text, options, answer_index, explanation, source_page, hints")
            .eq("quiz_id", value: quizId).order("sort_order").execute().value) ?? []
        let sources = quiz.options?.sources ?? [:]
        return Quiz(id: quiz.id, lang: Lang(rawValue: quiz.lang ?? "") ?? .tr, questions: rows.compactMap {
            guard let options = $0.options, options.count > 1 else { return nil }
            return QuizQuestion(id: $0.id, text: $0.text, options: options, answer: $0.answer_index ?? 0, why: $0.explanation ?? "",
                                page: $0.source_page, hints: $0.hints ?? [], materialId: sources[$0.id] ?? nil)
        })
    }

    /// The short check after a section in the reader: up to 3 of the lesson's questions from that section's pages.
    /// `seen`: questions the student already had in this check ("Yeni 3 soru" skips them). Questions on the
    /// student's weak topics (what they asked to add, wrong answers) come first.
    static func sectionCheck(materialId: String, pageFrom: Int, pageTo: Int, seen: [String] = []) async -> Quiz? {
        if let lesson = await latest(kind: "lesson_end", materialId: materialId) {
            let here = lesson.questions.filter { q in q.page.map { $0 >= pageFrom && $0 <= pageTo } ?? false }.filter { !seen.contains($0.id) }
            let weak = await weakQuestionIds(materialId: materialId, ids: here.map(\.id))
            let qs = Array((here.filter { weak.contains($0.id) } + here.filter { !weak.contains($0.id) }).prefix(3))
            return qs.isEmpty ? nil : Quiz(id: lesson.id, lang: lesson.lang, questions: qs)
        }
        return seen.isEmpty ? await latest(kind: "section_check", materialId: materialId) : nil
    }

    /// Which of these questions are about one of the student's weak topics in this lesson.
    static func weakQuestionIds(materialId: String, ids: [String]) async -> Set<String> {
        guard !ids.isEmpty else { return [] }
        struct Weak: Decodable { let topic_id: String }
        struct Q: Decodable { let id: String; let topic_id: String? }
        async let weakQ: [Weak] = supabase.from("topic_progress").select("topic_id, material_topics!inner(material_id)")
            .eq("state", value: "weak").eq("material_topics.material_id", value: materialId).execute().value
        async let qsQ: [Q] = supabase.from("quiz_questions").select("id, topic_id").in("id", values: ids).execute().value
        let topics = Set(((try? await weakQ) ?? []).map(\.topic_id))
        return Set(((try? await qsQ) ?? []).filter { $0.topic_id.map(topics.contains) ?? false }.map(\.id))
    }

    enum MoreResult { case ok, locked, budget, failed }

    /// "Yeni 3 soru" when the section has no unseen questions left: the server (Edge Function more-questions) writes
    /// new ones about the same pages (favouring the weak topics) and keeps them with the lesson. Costs a little AI.
    static func moreSectionQuestions(materialId: String, pageFrom: Int, pageTo: Int) async -> MoreResult {
        struct Body: Encodable { let material_id: String; let page_from, page_to, count: Int }
        do {
            try await supabase.functions.invoke("more-questions", options: FunctionInvokeOptions(
                body: Body(material_id: materialId, page_from: pageFrom, page_to: pageTo, count: 3)))
            return .ok
        } catch FunctionsError.httpError(let code, _) {
            return code == 403 ? .locked : code == 429 ? .budget : .failed
        } catch {
            return .failed
        }
    }

    /// The end-of-lesson exam: all the lesson's questions.
    static func lessonExam(materialId: String) async -> Quiz? {
        await latest(kind: "lesson_end", materialId: materialId)
    }

    struct Answer { let questionId: String; let chosen: Int?; let hints: Int; let confidence: Confidence? }

    /// Saves a finished try, then the server grades it (right/wrong, score, topic mastery, wrong "sure" answers to
    /// the "Hatalarım" cards). Returns the score (0–100) when the server answered.
    static func saveAttempt(quizId: String, answers: [Answer]) async -> Int? {
        guard let user = supabase.auth.currentUser, !answers.isEmpty else { return nil }
        let uid = user.id.uuidString.lowercased()
        let id = UUID().uuidString.lowercased()
        struct Attempt: Encodable { let id, quiz_id, user_id: String }
        struct Row: Encodable { let attempt_id, question_id, user_id: String; let chosen_index: Int?; let hints_used: Int; let confidence: String? }
        struct Finish: Encodable { let finished_at: String }
        struct Body: Encodable { let attempt_id: String }
        struct Graded: Decodable { let score: Double? }
        do {
            try await supabase.from("quiz_attempts").insert(Attempt(id: id, quiz_id: quizId, user_id: uid)).execute()
            try await supabase.from("quiz_answers").insert(answers.map {
                Row(attempt_id: id, question_id: $0.questionId, user_id: uid, chosen_index: $0.chosen, hints_used: $0.hints, confidence: $0.confidence?.rawValue)
            }).execute()
            try await supabase.from("quiz_attempts").update(Finish(finished_at: ISO8601DateFormatter().string(from: Date()))).eq("id", value: id).execute()
            let graded: Graded = try await supabase.functions.invoke("grade-quiz", options: FunctionInvokeOptions(body: Body(attempt_id: id)))
            return graded.score.map { Int($0.rounded()) }
        } catch {
            return nil
        }
    }
}
