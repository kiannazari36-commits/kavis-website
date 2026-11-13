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
        static let formatKeys = ["multiple_choice", "fill_blank", "true_false", "calculation", "other"]
        var types: [String: Int]
        /// Share (percent) of each question format; empty for styles found before formats were learned.
        var formats: [String: Int] = [:]
        var patterns: [String]
        var questions: Int
        var topTopics: [(title: String, count: Int)]
        var useInQuizzes: Bool

        static func == (a: Style, b: Style) -> Bool {
            a.types == b.types && a.formats == b.formats && a.patterns == b.patterns && a.questions == b.questions && a.useInQuizzes == b.useInQuizzes
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
        struct Dist: Decodable { let types: [String: Int]?; let formats: [String: Int]?; let patterns: [String]?; let questions: Int? }
        struct Topic: Decodable { let title: String; let count: Int }
        let distribution: Dist
        let top_topics: [Topic]?
        let use_in_quizzes: Bool?

        var style: Style {
            Style(types: distribution.types ?? [:], formats: distribution.formats ?? [:], patterns: distribution.patterns ?? [], questions: distribution.questions ?? 0,
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
    static func makeExamPack(courseId: String, types: [String] = [], count: Int = 10) async -> Result<(quizId: String, questions: Int), Failure> {
        struct Body: Encodable { let course_id: String; let count: Int; let styles: [String]; let types: [String] }
        struct Made: Decodable { let quiz_id: String; let questions: Int }
        do {
            let r: Made = try await supabase.functions.invoke("generate-quiz", options: FunctionInvokeOptions(body: Body(course_id: courseId, count: count, styles: [], types: types)))
            return .success((r.quiz_id, r.questions))
        } catch {
            return .failure(failure(error))
        }
    }

    /// The course's exam summaries (full "Sınav özeti" and short "Sınav gecesi özeti"), as lesson ids.
    static func examMaterials(courseId: String) async -> (summary: String?, brief: String?) {
        struct Row: Decodable { let id, kind: String }
        let rows: [Row] = (try? await supabase.from("materials").select("id, kind").eq("course_id", value: courseId)
            .in("kind", values: ["exam_summary", "exam_brief"]).order("created_at", ascending: false).execute().value) ?? []
        return (rows.first { $0.kind == "exam_summary" }?.id, rows.first { $0.kind == "exam_brief" }?.id)
    }

    /// The newest exam pack of the course ("Soruları çöz"), nil when none is made yet.
    static func latestExamPackId(courseId: String) async -> String? {
        struct Row: Decodable { let id: String }
        return (try? await supabase.from("quizzes").select("id").eq("kind", value: "exam_prep").eq("course_id", value: courseId)
            .order("created_at", ascending: false).limit(1).execute().value as [Row])?.first?.id
    }

    enum SummaryResult { case made(String), mismatch, failed(Failure) }

    /// "Sınav özeti" (AI): the asked topics explained from the student's PDFs, as a reading page; `brief` = the short exam-night one.
    static func makeExamSummary(courseId: String, brief: Bool) async -> SummaryResult {
        struct Body: Encodable { let course_id: String; let mode: String }
        struct Made: Decodable { let material_id: String }
        do {
            let r: Made = try await supabase.functions.invoke("exam-summary", options: FunctionInvokeOptions(body: Body(course_id: courseId, mode: brief ? "brief" : "full")))
            return .made(r.material_id)
        } catch {
            if case let FunctionsError.httpError(_, data) = error, String(data: data, encoding: .utf8)?.contains("mismatch") == true { return .mismatch }
            return .failed(failure(error))
        }
    }
}
