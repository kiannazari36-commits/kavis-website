import Foundation
import Supabase

/// One exam of one course (table course_exams: "Vize · 19 Ekim"). The student writes them.
struct CourseExam: Identifiable, Equatable {
    enum Kind: String, CaseIterable { case midterm, final, makeup }
    let id: String
    let courseId: String
    let kind: Kind
    /// ISO day, "2026-10-19".
    let date: String
}

/// "Sınav merkezi": the exam week (from the courses' exam days) and exams put together on the server from the
/// questions already written for the student's lessons (Edge Function build-exam, no AI).
enum ExamsAPI {
    /// Upcoming exams (today or later), nearest first.
    static func upcoming() async -> [CourseExam] {
        struct Row: Decodable { let id, course_id, kind, exam_date: String }
        let rows: [Row] = (try? await supabase.from("course_exams").select("id, course_id, kind, exam_date")
            .gte("exam_date", value: CoursesAPI.todayISO()).order("exam_date").execute().value) ?? []
        return rows.compactMap { r in CourseExam.Kind(rawValue: r.kind).map { CourseExam(id: r.id, courseId: r.course_id, kind: $0, date: r.exam_date) } }
    }

    /// Saves the exam week: each course gets its exam of this kind on the given day (an upcoming one of the same kind
    /// is moved, otherwise a new one is added).
    static func saveWeek(kind: CourseExam.Kind, days: [String: String], existing: [CourseExam]) async -> Bool {
        guard let uid = supabase.auth.currentUser?.id.uuidString.lowercased() else { return false }
        struct Move: Encodable { let exam_date: String }
        struct New: Encodable { let user_id, course_id, kind, exam_date: String }
        do {
            for (course, day) in days {
                if let old = existing.first(where: { $0.courseId == course && $0.kind == kind }) {
                    try await supabase.from("course_exams").update(Move(exam_date: day)).eq("id", value: old.id).execute()
                } else {
                    try await supabase.from("course_exams").insert(New(user_id: uid, course_id: course, kind: kind.rawValue, exam_date: day)).execute()
                }
            }
            return true
        } catch {
            return false
        }
    }

    /// How many questions are ready per course.
    static func readyQuestions() async -> [String: Int] {
        struct Body: Encodable { let action = "overview" }
        struct Row: Decodable { let course_id: String; let questions: Int }
        struct Res: Decodable { let courses: [Row] }
        guard let r: Res = try? await supabase.functions.invoke("build-exam", options: FunctionInvokeOptions(body: Body())) else { return [:] }
        return Dictionary(uniqueKeysWithValues: r.courses.map { ($0.course_id, $0.questions) })
    }

    enum BuildResult { case ok(String), empty, failed }

    /// Puts an exam together: one course or several, `count` questions, half on weak topics when `weakFocus`.
    static func build(courseIds: [String], count: Int, weakFocus: Bool) async -> BuildResult {
        struct Body: Encodable { let action = "build"; let course_ids: [String]; let count: Int; let weak_focus: Bool }
        struct Res: Decodable { let quiz_id: String }
        do {
            let r: Res = try await supabase.functions.invoke("build-exam", options: FunctionInvokeOptions(
                body: Body(course_ids: courseIds, count: count, weak_focus: weakFocus)))
            return .ok(r.quiz_id)
        } catch FunctionsError.httpError(404, _) {
            return .empty
        } catch {
            return .failed
        }
    }
}
