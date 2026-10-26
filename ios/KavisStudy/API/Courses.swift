import Foundation
import Supabase

/// The courses a student takes this term (chosen after sign up).
struct TermSetup: Codable, Equatable {
    /// Course names as the design writes them (Turkish) or as the student typed them.
    var courses: [String]
    /// Courses the student has already studied (the assistant suggests a short placement test for these).
    var started: [String]
}

/// The student's courses and their lessons (tables courses, course_exams, materials, reading_progress,
/// study_sessions; Row Level Security: own rows only), the same as the web's "Derslerim".
enum CoursesAPI {
    private struct Row: Decodable {
        struct Exam: Decodable { let kind: String; let exam_date: String }
        struct Progress: Decodable { let percent_read: Double }
        struct Material: Decodable {
            let id: String
            let title: String
            let kind: String
            let parent_id: String?
            let page_count: Int?
            let reading_progress: [Progress]?
        }
        let id: String
        let name: String
        let short_name: String?
        let color: CourseColor
        let language: String?
        let course_exams: [Exam]?
        let materials: [Material]?
    }
    private struct Session: Decodable { let material_id: String?; let minutes: Double? }

    /// The last list from the server, so screens can show something at once.
    private(set) static var lastCourses: [Course] = []

    static func listCourses() async -> [Course] {
        do {
            async let rowsQ: [Row] = supabase.from("courses")
                .select("id, name, short_name, color, language, course_exams(kind, exam_date), materials(id, title, kind, parent_id, page_count, reading_progress(percent_read))")
                .is("archived_at", value: nil)
                .order("sort_order")
                .order("created_at", referencedTable: "materials")
                .execute().value
            async let sessionsQ: [Session] = supabase.from("study_sessions").select("material_id, minutes").execute().value
            let (rows, sessions) = try await (rowsQ, sessionsQ)
            var minutes: [String: Double] = [:]
            for s in sessions { if let m = s.material_id { minutes[m, default: 0] += s.minutes ?? 0 } }
            let today = todayISO()
            let list = rows.map { r -> Course in
                let next = (r.course_exams ?? []).filter { $0.exam_date >= today }.min { $0.exam_date < $1.exam_date }
                let pdfs = (r.materials ?? []).filter { $0.parent_id == nil && ($0.kind == "pdf" || $0.kind == "photo") }.map { m in
                    Pdf(id: m.id, title: same(m.title), read: Int((m.reading_progress?.first?.percent_read ?? 0).rounded()),
                        minutes: Int((minutes[m.id] ?? 0).rounded()), pages: m.page_count ?? 0)
                }
                return Course(id: r.id, name: same(r.name), short: r.short_name.map(same), color: r.color,
                              language: r.language.flatMap(Lang.init(rawValue:)) ?? .tr, exam: examLabel(next?.kind, next?.exam_date),
                              examDate: next?.exam_date, rank: 0, pdfs: pdfs)
            }
            lastCourses = list
            return list
        } catch {
            return lastCourses
        }
    }

    static func getCourse(id: String) async -> Course? {
        await listCourses().first { $0.id == id }
    }

    static func getPdf(courseId: String, pdfId: String) async -> (course: Course, pdf: Pdf)? {
        guard let course = await getCourse(id: courseId), let pdf = course.pdfs.first(where: { $0.id == pdfId }) else { return nil }
        return (course, pdf)
    }

    private static let colors: [CourseColor] = [.red, .amb, .vio, .grn, .teal]

    /// New courses (own rows), with the next free colours; "started" ones get a placement test later.
    @discardableResult
    static func createCourses(_ names: [String], started: [String] = []) async -> Bool {
        guard let uid = supabase.auth.currentUser?.id, !names.isEmpty else { return false }
        let count = (try? await supabase.from("courses").select("id", head: true, count: .exact).execute().count) ?? 0
        struct Insert: Encodable { let user_id: UUID; let name: String; let color: String; let term: String; let started_before: Bool; let sort_order: Int }
        let term = termName()
        let rows = names.enumerated().map { i, name in
            Insert(user_id: uid, name: name.trimmingCharacters(in: .whitespaces), color: colors[(count + i) % colors.count].rawValue,
                   term: term, started_before: started.contains(name), sort_order: count + i)
        }
        return (try? await supabase.from("courses").insert(rows).execute()) != nil
    }

    /// Creates the term's course folders (end of the first steps).
    static func createTermFolders(_ setup: TermSetup) async -> TermSetup {
        await createCourses(setup.courses, started: setup.started)
        return setup
    }

    /// The term like the design: "2026–2027 Güz" from August to January, else "Bahar".
    static func termName(_ date: Date = Date()) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date)
        let m = c.month ?? 1, y = c.year ?? 2026
        let start = m >= 8 ? y : y - 1
        return "\(start)–\(start + 1) \(m >= 8 || m == 1 ? "Güz" : "Bahar")"
    }

    /// Totals used on a course card and folder header.
    static func stats(_ c: Course) -> (minutes: Int, pages: Int, percent: Int) {
        let minutes = c.pdfs.reduce(0) { $0 + $1.minutes }
        let pages = c.pdfs.reduce(0) { $0 + $1.pages }
        let readPages = c.pdfs.reduce(0.0) { $0 + Double($1.pages * $1.read) / 100 }
        return (minutes, pages, pages > 0 ? Int((readPages / Double(pages) * 100).rounded()) : 0)
    }

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Today as "2026-10-26" (local day).
    static func todayISO() -> String { isoFormatter.string(from: Date()) }

    static func daysUntil(_ iso: String, today: String = todayISO()) -> Int {
        guard let a = isoFormatter.date(from: iso), let b = isoFormatter.date(from: today) else { return 0 }
        return Int((a.timeIntervalSince(b) / 86_400).rounded())
    }

    /// A course's own words are the same in every language (the teacher's / student's names are never translated).
    private static func same(_ text: String) -> L10n { L10n(tr: text, en: text, fa: text, ar: text) }

    /// The next exam as on the web: "Vize · 19 Ekim" / "Midterm · Oct 19"; no exam: "Sınav tarihi yok".
    static func examLabel(_ kind: String?, _ iso: String?) -> L10n {
        guard let kind, let iso, let date = isoFormatter.date(from: iso) else {
            return L10n(tr: "Sınav tarihi yok", en: "No exam date", fa: "تاریخ امتحان ندارد", ar: "لا يوجد موعد امتحان")
        }
        let names: [String: [String]] = [
            "midterm": ["Vize", "Midterm", "میان‌ترم", "منتصف الفصل"],
            "final": ["Final", "Final", "پایان‌ترم", "النهائي"],
            "makeup": ["Bütünleme", "Make-up", "ترمیمی", "الدور الثاني"],
            "quiz": ["Quiz", "Quiz", "کوییز", "اختبار قصير"],
        ]
        let n = names[kind] ?? ["Sınav", "Exam", "امتحان", "امتحان"]
        func day(_ locale: String, _ format: String) -> String {
            let f = DateFormatter()
            f.locale = Locale(identifier: locale)
            f.setLocalizedDateFormatFromTemplate(format)
            return f.string(from: date)
        }
        return L10n(tr: "\(n[0]) · \(day("tr_TR", "d MMMM"))", en: "\(n[1]) · \(day("en_US", "MMM d"))",
                    fa: "\(n[2]) · \(day("fa_IR@calendar=gregorian", "d MMMM"))", ar: "\(n[3]) · \(day("ar", "d MMMM"))")
    }
}
