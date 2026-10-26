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

    /// The short check after a section in the reader: up to 3 of the lesson's questions from that section's pages.
    static func sectionCheck(materialId: String, pageFrom: Int, pageTo: Int) async -> Quiz? {
        if let lesson = await latest(kind: "lesson_end", materialId: materialId) {
            let qs = Array(lesson.questions.filter { q in q.page.map { $0 >= pageFrom && $0 <= pageTo } ?? false }.prefix(3))
            return qs.isEmpty ? nil : Quiz(id: lesson.id, lang: lesson.lang, questions: qs)
        }
        return await latest(kind: "section_check", materialId: materialId)
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
