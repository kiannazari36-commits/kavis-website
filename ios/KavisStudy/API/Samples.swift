import Foundation
import Supabase

/// "Soru örneklerim", the same as the web (`web/src/api/samples.ts`): the lecturer's old or class questions per course
/// (table question_samples, files in the private "question-samples" bucket). The server reads them and finds the
/// lecturer's question style (Edge analyze-style → teacher_styles), which then shapes new questions (Edge generate-quiz).
enum SamplesAPI {
    struct Sample: Identifiable, Equatable {
        let id: String
        /// photo | pdf | text
        let kind: String
        let title: String
        let questions: Int?
    }

    struct Style: Equatable {
        static let types = ["case", "side_effects", "dose", "knowledge", "structure"]
        var types: [String: Int]
        var patterns: [String]
        var questions: Int
        var topTopics: [(title: String, count: Int)]
        var useInQuizzes: Bool

        static func == (a: Style, b: Style) -> Bool {
            a.types == b.types && a.patterns == b.patterns && a.questions == b.questions && a.useInQuizzes == b.useInQuizzes
                && a.topTopics.map(\.title) == b.topTopics.map(\.title)
        }
    }

    enum Failure: Error { case locked, budget, failed }

    static func list(courseId: String) async -> [Sample] {
        struct Row: Decodable { let id, kind: String; let title: String?; let question_count: Int? }
        let rows: [Row] = (try? await supabase.from("question_samples").select("id, kind, title, question_count")
            .eq("course_id", value: courseId).order("created_at", ascending: false).execute().value) ?? []
        return rows.map { Sample(id: $0.id, kind: $0.kind, title: $0.title ?? "", questions: $0.question_count) }
    }

    /// A photo (JPEG) or a PDF of questions: each file is one sample (at most 15 MB).
    static func addFile(_ data: Data, pdf: Bool, title: String, courseId: String) async -> Bool {
        guard let user = supabase.auth.currentUser, data.count <= 15 * 1_048_576 else { return false }
        let uid = user.id.uuidString.lowercased()
        let path = "\(uid)/\(courseId)/\(UUID().uuidString.lowercased()).\(pdf ? "pdf" : "jpg")"
        let bucket = supabase.storage.from("question-samples")
        do {
            try await bucket.upload(path, data: data, options: FileOptions(contentType: pdf ? "application/pdf" : "image/jpeg"))
        } catch {
            return false
        }
        struct Row: Encodable { let user_id, course_id, kind, title, storage_path: String }
        do {
            try await supabase.from("question_samples").insert(Row(user_id: uid, course_id: courseId, kind: pdf ? "pdf" : "photo", title: title, storage_path: path)).execute()
            return true
        } catch {
            _ = try? await bucket.remove(paths: [path])
            return false
        }
    }

    /// Questions typed or pasted ("Yazarak").
    static func addText(_ text: String, title: String, courseId: String) async -> Bool {
        guard let user = supabase.auth.currentUser else { return false }
        struct Row: Encodable { let user_id, course_id, kind, title, text: String }
        return (try? await supabase.from("question_samples")
            .insert(Row(user_id: user.id.uuidString.lowercased(), course_id: courseId, kind: "text", title: title, text: text.trimmingCharacters(in: .whitespacesAndNewlines)))
            .execute()) != nil
    }

    static func delete(_ id: String) async {
        struct Path: Decodable { let storage_path: String? }
        let path = (try? await supabase.from("question_samples").select("storage_path").eq("id", value: id).limit(1).execute().value as [Path])?.first?.storage_path
        guard (try? await supabase.from("question_samples").delete().eq("id", value: id).execute()) != nil else { return }
        if let path { _ = try? await supabase.storage.from("question-samples").remove(paths: [path]) }
    }

    private struct StyleRow: Decodable {
        struct Dist: Decodable { let types: [String: Int]?; let patterns: [String]?; let questions: Int? }
        struct Topic: Decodable { let title: String; let count: Int }
        let distribution: Dist
        let top_topics: [Topic]?
        let use_in_quizzes: Bool?

        var style: Style {
            Style(types: distribution.types ?? [:], patterns: distribution.patterns ?? [], questions: distribution.questions ?? 0,
                  topTopics: (top_topics ?? []).map { ($0.title, $0.count) }, useInQuizzes: use_in_quizzes ?? true)
        }
    }

    static func style(courseId: String) async -> Style? {
        (try? await supabase.from("teacher_styles").select("distribution, top_topics, use_in_quizzes")
            .eq("course_id", value: courseId).limit(1).execute().value as [StyleRow])?.first?.style
    }

    private static func failure(_ error: Error) -> Failure {
        if case let FunctionsError.httpError(code, _) = error { return code == 403 ? .locked : code == 429 ? .budget : .failed }
        return .failed
    }

    /// "Soru tarzını çıkar": the server reads all samples of the course (AI).
    static func analyze(courseId: String) async -> Result<Style, Failure> {
        struct Body: Encodable { let course_id: String }
        do {
            let r: StyleRow = try await supabase.functions.invoke("analyze-style", options: FunctionInvokeOptions(body: Body(course_id: courseId)))
            return .success(r.style)
        } catch {
            return .failure(failure(error))
        }
    }

    /// "Sınavlarda bu tarzı kullan".
    static func setUseInQuizzes(courseId: String, _ on: Bool) async {
        struct U: Encodable { let use_in_quizzes: Bool }
        _ = try? await supabase.from("teacher_styles").update(U(use_in_quizzes: on)).eq("course_id", value: courseId).execute()
    }

    /// "Bu tarzda yeni sorular üret": a new exam pack for the course (Edge generate-quiz, AI). Returns the quiz.
    static func makeExamPack(courseId: String) async -> Result<(quizId: String, questions: Int), Failure> {
        struct Body: Encodable { let course_id: String; let count: Int; let styles: [String] }
        struct Made: Decodable { let quiz_id: String; let questions: Int }
        do {
            let r: Made = try await supabase.functions.invoke("generate-quiz", options: FunctionInvokeOptions(body: Body(course_id: courseId, count: 10, styles: [])))
            return .success((r.quiz_id, r.questions))
        } catch {
            return .failure(failure(error))
        }
    }
}
