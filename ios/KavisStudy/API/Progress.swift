import Foundation
import Supabase

/// "İlerleme": everything is computed from the student's own rows, like the web (`web/src/api/progress.ts`).
/// Scores and levels are written by the server (grade-quiz); minutes come from the reading stopwatch.
struct ProgressData {
    /// Minutes per weekday this week, Monday first.
    var weekMinutes: [Int] = Array(repeating: 0, count: 7)
    /// Days of this month with study time, and exam days of this month (day numbers).
    var studiedDays: Set<Int> = []
    var examDays: Set<Int> = []
    var studiedDaysCount = 0
    var streak = 0
    var lastScore: Int?
    var bestScore: Int?
    /// beginner | developing | good | very_good | expert (from grade-quiz)
    var level: String?
    var pagesRead = 0
    var pagesTotal = 0
    var dueCards = 0
    /// Most tapped hard words and mistakes made while "sure", with how often.
    var words: [(String, Int)] = []
    var dangerous: [(String, Int)] = []
    /// The 2-hour window with the best average score (at least 2 exams), and the average after 22:00.
    var bestHours: (from: Int, to: Int, rate: Int, late: Int?)?
    /// Last 4 weeks (this one included): minutes per week on average.
    var fourWeekAverage = 0
    /// Time per PDF this week (title, minutes), longest first.
    var perPdf: [(String, Int)] = []
    /// Days of the shown month with cards or reviews due (today or later), and the days of the exam period / exam week.
    var nextReviewDays: Set<Int> = []
    var examWeekDays: Set<Int> = []
    /// The next exam period ("Vize · 19–23 Ekim"): kind, first and last day (ISO) and the days left until it starts.
    var exam: (kind: String, start: String, end: String, daysLeft: Int)?

    var isEmpty: Bool { weekMinutes.allSatisfy { $0 == 0 } && lastScore == nil && pagesRead == 0 && studiedDays.isEmpty }
}

enum ProgressAPI {
    private static let levels = ["beginner", "developing", "good", "very_good", "expert"]
    static func levelIndex(_ level: String?) -> Int? { level.flatMap { levels.firstIndex(of: $0) } }

    /// Days are the student's days in Istanbul, like the server's `daily_minutes` view.
    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current
        c.firstWeekday = 2
        return c
    }

    private static let dayFormat: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Istanbul")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// `course` limits the numbers to one course (nil = all); `month` is the month of the calendar.
    static func load(course: String? = nil, month: Date = Date()) async -> ProgressData {
        var p = ProgressData()
        let cal = calendar
        let today = CoursesAPI.todayISO()
        let monday = PlanAPI.monday()
        let mondayDate = dayFormat.date(from: monday) ?? Date()
        let fourWeeksAgo = cal.date(byAdding: .day, value: -21, to: mondayDate) ?? mondayDate
        let monthStartDate = cal.dateInterval(of: .month, for: month)?.start ?? month
        let monthEndDate = cal.dateInterval(of: .month, for: month)?.end ?? month
        let monthStart = dayFormat.string(from: monthStartDate)
        let monthEnd = dayFormat.string(from: monthEndDate)
        let from = min(dayFormat.string(from: fourWeeksAgo), monthStart)

        struct Material: Decodable { let title: String }
        struct Session: Decodable { let started_at: Date; let minutes: Double?; let material_id: String?; let materials: Material? }
        struct Attempt: Decodable { let score: Double; let level: String?; let started_at: Date; let quizzes: QuizRef? }
        struct QuizRef: Decodable { let course_id: String? }
        struct Exam: Decodable { let exam_date: String; let course_id: String; let kind: String }
        struct Period: Decodable { let kind: String; let start_date: String; let end_date: String }
        struct Term: Decodable { let surface: String }
        struct Tap: Decodable { let taps: Int; let material_terms: Term? }
        struct Question: Decodable { let text: String }
        struct Wrong: Decodable { let quiz_questions: Question? }
        struct Deck: Decodable { let course_id: String? }
        struct Due: Decodable { let due_at: Date; let card_decks: Deck? }

        var sessionsQuery = supabase.from("study_sessions").select("started_at, minutes, material_id, materials(title)").gte("started_at", value: from)
        if let course { sessionsQuery = sessionsQuery.eq("course_id", value: course) }
        async let sessionsQ: [Session] = sessionsQuery.execute().value
        async let streakQ: Int = supabase.rpc("study_streak").execute().value
        async let attemptsQ: [Attempt] = supabase.from("quiz_attempts").select("score, level, started_at, quizzes(course_id)").not("score", operator: .is, value: "null").order("started_at").execute().value
        async let examsQ: [Exam] = supabase.from("course_exams").select("exam_date, course_id, kind").gte("exam_date", value: min(today, monthStart)).execute().value
        async let periodsQ: [Period] = supabase.from("exam_periods").select("kind, start_date, end_date").gte("end_date", value: min(today, monthStart)).order("start_date").execute().value
        async let dueQ: [Due] = supabase.from("flashcards").select("due_at, card_decks(course_id)").gte("due_at", value: monthStart).lt("due_at", value: monthEnd).execute().value
        async let tapsQ: [Tap] = supabase.from("term_lookups").select("taps, material_terms(surface)").order("taps", ascending: false).limit(20).execute().value
        async let wrongQ: [Wrong] = supabase.from("quiz_answers").select("quiz_questions(text)").eq("confidence", value: "sure").eq("correct", value: false).execute().value
        async let cardsQ = CardsAPI.dueCards(courseId: course, limit: 200)
        async let coursesQ = CoursesAPI.listCourses()

        // Study time by day and by PDF.
        let sessions = (try? await sessionsQ) ?? []
        var perDay: [String: Double] = [:]
        var perMaterial: [String: (String, Double)] = [:]
        for s in sessions {
            let day = dayFormat.string(from: s.started_at)
            perDay[day, default: 0] += s.minutes ?? 0
            if day >= monday, let id = s.material_id, let title = s.materials?.title {
                perMaterial[id] = (title, (perMaterial[id]?.1 ?? 0) + (s.minutes ?? 0))
            }
        }
        for (i, day) in (0..<7).map({ addDays(monday, $0) }).enumerated() { p.weekMinutes[i] = Int((perDay[day] ?? 0).rounded()) }
        let lastFour = perDay.filter { $0.key >= dayFormat.string(from: fourWeeksAgo) && $0.key <= addDays(monday, 6) }.values.reduce(0, +)
        p.fourWeekAverage = Int((lastFour / 4).rounded())
        p.perPdf = perMaterial.values.map { ($0.0, Int($0.1.rounded())) }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.prefix(3).map { $0 }
        for (day, m) in perDay where day >= monthStart && day < monthEnd && m >= 1 {
            if let d = Int(day.suffix(2)) { p.studiedDays.insert(d) }
        }
        p.studiedDaysCount = p.studiedDays.count
        p.streak = (try? await streakQ) ?? 0

        let attempts = ((try? await attemptsQ) ?? []).filter { course == nil || $0.quizzes?.course_id == course }
        p.lastScore = attempts.last.map { Int($0.score.rounded()) }
        p.bestScore = attempts.map { Int($0.score.rounded()) }.max()
        p.level = attempts.last?.level
        p.bestHours = bestHours(attempts.map { ($0.score, Calendar.current.component(.hour, from: $0.started_at)) })

        // Calendar marks: exam days, exam period (exam week), cards due.
        let exams = ((try? await examsQ) ?? []).filter { course == nil || $0.course_id == course }
        for e in exams where e.exam_date >= monthStart && e.exam_date < monthEnd {
            if let d = Int(e.exam_date.suffix(2)) { p.examDays.insert(d) }
        }
        let periods = (try? await periodsQ) ?? []
        for period in periods {
            var day = period.start_date
            var guardCount = 0
            while day <= period.end_date, guardCount < 60 {
                if day >= monthStart && day < monthEnd, let d = Int(day.suffix(2)) { p.examWeekDays.insert(d) }
                day = addDays(day, 1)
                guardCount += 1
            }
        }
        if let next = periods.first(where: { $0.end_date >= today }) {
            p.exam = (next.kind, next.start_date, next.end_date, max(0, CoursesAPI.daysUntil(next.start_date)))
        } else if let next = exams.filter({ $0.exam_date >= today }).min(by: { $0.exam_date < $1.exam_date }) {
            p.exam = (next.kind, next.exam_date, next.exam_date, max(0, CoursesAPI.daysUntil(next.exam_date)))
        }
        for due in (try? await dueQ) ?? [] where course == nil || due.card_decks?.course_id == course {
            let day = dayFormat.string(from: due.due_at)
            if day >= today, let d = Int(day.suffix(2)) { p.nextReviewDays.insert(d) }
        }

        var words: [String: Int] = [:]
        for t in (try? await tapsQ) ?? [] { if let w = t.material_terms?.surface { words[w, default: 0] += t.taps } }
        p.words = words.sorted { $0.value > $1.value }.prefix(6).map { ($0.key, $0.value) }
        var wrong: [String: Int] = [:]
        // Test questions keep their options after an empty line; only the question is shown.
        for w in (try? await wrongQ) ?? [] { if let q = w.quiz_questions?.text { wrong[q.components(separatedBy: "\n\n")[0], default: 0] += 1 } }
        p.dangerous = wrong.sorted { $0.value > $1.value }.prefix(4).map { ($0.key, $0.value) }

        p.dueCards = await cardsQ.count
        let courses = await coursesQ
        for c in courses where course == nil || c.id == course {
            let s = CoursesAPI.stats(c)
            p.pagesTotal += s.pages
            p.pagesRead += Int((Double(s.pages) * Double(s.percent) / 100).rounded())
        }
        return p
    }

    private static func addDays(_ day: String, _ n: Int) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: day) else { return day }
        return f.string(from: d.addingTimeInterval(Double(n) * 86_400 + 3_600))
    }

    /// Same rule as the web: the 2-hour window (06–24) with the best average score, at least 2 exams in it.
    static func bestHours(_ all: [(score: Double, hour: Int)]) -> (from: Int, to: Int, rate: Int, late: Int?)? {
        var best: (from: Int, to: Int, rate: Int, late: Int?)?
        for h in 6...22 {
            let inside = all.filter { $0.hour >= h && $0.hour < h + 2 }
            guard inside.count >= 2 else { continue }
            let rate = Int((inside.map(\.score).reduce(0, +) / Double(inside.count)).rounded())
            if best == nil || rate > best!.rate { best = (h, h + 2, rate, nil) }
        }
        let late = all.filter { $0.hour >= 22 || $0.hour < 4 }
        if best != nil, !late.isEmpty { best!.late = Int((late.map(\.score).reduce(0, +) / Double(late.count)).rounded()) }
        return best
    }
}

/// The numbers on the profile screen, all from the student's own rows.
struct ProfileStats: Equatable {
    var minutes = 0
    var streak = 0
    var courses = 0
    var pdfs = 0
    /// Questions in the lecturer-style samples the student added ("Soru örneklerim").
    var sampleQuestions = 0
}

extension ProgressAPI {
    static func profileStats() async -> ProfileStats {
        struct Session: Decodable { let minutes: Double? }
        struct Sample: Decodable { let question_count: Int? }
        async let sessionsQ: [Session] = supabase.from("study_sessions").select("minutes").execute().value
        async let streakQ: Int = supabase.rpc("study_streak").execute().value
        async let samplesQ: [Sample] = supabase.from("question_samples").select("question_count").execute().value
        async let coursesQ = CoursesAPI.listCourses()
        var s = ProfileStats()
        s.minutes = Int(((try? await sessionsQ) ?? []).reduce(0) { $0 + ($1.minutes ?? 0) }.rounded())
        s.streak = (try? await streakQ) ?? 0
        s.sampleQuestions = ((try? await samplesQ) ?? []).reduce(0) { $0 + ($1.question_count ?? 0) }
        let courses = await coursesQ
        s.courses = courses.count
        s.pdfs = courses.reduce(0) { $0 + $1.pdfs.count }
        return s
    }
}
