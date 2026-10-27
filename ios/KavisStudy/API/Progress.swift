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

    var isEmpty: Bool { weekMinutes.allSatisfy { $0 == 0 } && lastScore == nil && pagesRead == 0 && studiedDays.isEmpty }
}

enum ProgressAPI {
    private static let levels = ["beginner", "developing", "good", "very_good", "expert"]
    static func levelIndex(_ level: String?) -> Int? { level.flatMap { levels.firstIndex(of: $0) } }

    static func load() async -> ProgressData {
        var p = ProgressData()
        let today = CoursesAPI.todayISO()
        let monday = PlanAPI.monday()
        let monthStart = String(today.prefix(8)) + "01"

        struct Minutes: Decodable { let day: String; let minutes: Double? }
        struct Attempt: Decodable { let score: Double; let level: String?; let started_at: Date }
        struct Exam: Decodable { let exam_date: String }
        struct Term: Decodable { let surface: String }
        struct Tap: Decodable { let taps: Int; let material_terms: Term? }
        struct Question: Decodable { let text: String }
        struct Wrong: Decodable { let quiz_questions: Question? }

        async let minutesQ: [Minutes] = supabase.from("daily_minutes").select("day, minutes").gte("day", value: min(monday, monthStart)).execute().value
        async let streakQ: Int = supabase.rpc("study_streak").execute().value
        async let attemptsQ: [Attempt] = supabase.from("quiz_attempts").select("score, level, started_at").not("score", operator: .is, value: "null").order("started_at").execute().value
        async let examsQ: [Exam] = supabase.from("course_exams").select("exam_date").gte("exam_date", value: monthStart).execute().value
        async let tapsQ: [Tap] = supabase.from("term_lookups").select("taps, material_terms(surface)").order("taps", ascending: false).limit(20).execute().value
        async let wrongQ: [Wrong] = supabase.from("quiz_answers").select("quiz_questions(text)").eq("confidence", value: "sure").eq("correct", value: false).execute().value
        async let cardsQ = CardsAPI.dueCards(limit: 200)
        async let coursesQ = CoursesAPI.listCourses()

        let minutes = (try? await minutesQ) ?? []
        for (i, day) in (0..<7).map({ addDays(monday, $0) }).enumerated() {
            p.weekMinutes[i] = Int((minutes.first { $0.day == day }?.minutes ?? 0).rounded())
        }
        for m in minutes where m.day.hasPrefix(String(today.prefix(8))) && (m.minutes ?? 0) >= 1 {
            if let d = Int(m.day.suffix(2)) { p.studiedDays.insert(d) }
        }
        p.studiedDaysCount = p.studiedDays.count
        p.streak = (try? await streakQ) ?? 0

        let attempts = (try? await attemptsQ) ?? []
        p.lastScore = attempts.last.map { Int($0.score.rounded()) }
        p.bestScore = attempts.map { Int($0.score.rounded()) }.max()
        p.level = attempts.last?.level
        p.bestHours = bestHours(attempts.map { ($0.score, Calendar.current.component(.hour, from: $0.started_at)) })

        for e in (try? await examsQ) ?? [] where e.exam_date.hasPrefix(String(today.prefix(8))) {
            if let d = Int(e.exam_date.suffix(2)) { p.examDays.insert(d) }
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
        for c in courses {
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
