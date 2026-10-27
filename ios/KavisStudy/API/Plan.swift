import Foundation
import Supabase

/// A task of the week plan (`plan_items`), made by the server (Edge Function build-plan: rules only, no AI, free).
struct PlanTask: Identifiable, Equatable {
    let id: String
    /// YYYY-MM-DD
    let day: String
    let courseId: String?
    let materialId: String?
    /// read | review | quiz | cards | exam_prep | mistakes | placement
    let kind: String
    let title: String
    let minutes: Int
    /// Why it is in the plan (content language), e.g. "zayıf konun · %38".
    let why: String
    /// reader | quiz | cards | review | exam_prep
    let target: String
    var status: String
}

/// Today's short review ("Bugün tekrar günü"), made by the daily planner.
struct TodayReview: Equatable {
    let id: String
    let title: String
    let minutes: Int
    let cards: Int
    let questions: Int
}

/// The study plan, the same as the web (`web/src/api/plan.ts`).
enum PlanAPI {
    private static let iso: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Monday of this week.
    static func monday(_ today: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let start = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return iso.string(from: start)
    }

    /// This week's plan: made again first when it is missing or was made on an earlier day (like the web with the
    /// Kavis plan on).
    static func weekTasks() async -> [PlanTask] {
        struct Plan: Decodable { let id: String; let generated_at: Date }
        let week = monday()
        var plan: Plan? = (try? await supabase.from("study_plans").select("id, generated_at").eq("week_start", value: week).limit(1).execute().value as [Plan])?.first
        let today = CoursesAPI.todayISO()
        if plan == nil || iso.string(from: plan!.generated_at) < today {
            await runPlanner("build")
            plan = (try? await supabase.from("study_plans").select("id, generated_at").eq("week_start", value: week).limit(1).execute().value as [Plan])?.first
        }
        guard let plan else { return [] }
        struct Row: Decodable {
            let id, day, kind, title, target, status: String
            let course_id, material_id, why: String?
            let minutes: Int
        }
        let rows: [Row] = (try? await supabase.from("plan_items")
            .select("id, day, course_id, material_id, kind, title, minutes, why, target, status")
            .eq("plan_id", value: plan.id).neq("status", value: "removed").order("day").order("sort_order").execute().value) ?? []
        return rows.map { PlanTask(id: $0.id, day: $0.day, courseId: $0.course_id, materialId: $0.material_id, kind: $0.kind, title: $0.title,
                                   minutes: $0.minutes, why: $0.why ?? "", target: $0.target, status: $0.status) }
    }

    /// Asks the server to plan ('build' makes the rest of this week again; done tasks stay). The phone's own date is sent.
    static func runPlanner(_ action: String) async {
        struct Body: Encodable { let action, today: String }
        _ = try? await supabase.functions.invoke("build-plan", options: FunctionInvokeOptions(body: Body(action: action, today: CoursesAPI.todayISO())))
    }

    static func setDone(_ id: String, _ done: Bool) async {
        struct Update: Encodable { let status: String; let done_at: String? }
        _ = try? await supabase.from("plan_items").update(Update(status: done ? "done" : "todo", done_at: done ? ISO8601DateFormatter().string(from: Date()) : nil))
            .eq("id", value: id).execute()
    }

    static func todayReview() async -> TodayReview? {
        struct Content: Decodable { let cards: Int?; let questions: Int? }
        struct Material: Decodable { let title: String }
        struct Row: Decodable { let id: String; let minutes: Int; let content: Content; let materials: Material? }
        guard let r = (try? await supabase.from("review_sessions").select("id, minutes, content, materials(title)")
            .eq("scheduled_for", value: CoursesAPI.todayISO()).eq("status", value: "todo").limit(1).execute().value as [Row])?.first else { return nil }
        return TodayReview(id: r.id, title: r.materials?.title ?? "", minutes: r.minutes, cards: r.content.cards ?? 0, questions: r.content.questions ?? 0)
    }

    /// One review of the daily planner with its lesson (the "Bugünün tekrarı" screen, web `getReview`).
    struct Review: Equatable {
        let id: String
        let materialId: String?
        let courseId: String?
        let title: String
        let minutes: Int
        let cards: Int
        let status: String
    }

    static func review(_ id: String) async -> Review? {
        struct Content: Decodable { let cards: Int? }
        struct Material: Decodable { let title: String }
        struct Row: Decodable { let id: String; let material_id, course_id: String?; let minutes: Int; let status: String; let content: Content; let materials: Material? }
        guard let r = (try? await supabase.from("review_sessions").select("id, material_id, course_id, minutes, content, status, materials(title)")
            .eq("id", value: id).limit(1).execute().value as [Row])?.first else { return nil }
        return Review(id: r.id, materialId: r.material_id, courseId: r.course_id, title: r.materials?.title ?? "", minutes: r.minutes, cards: r.content.cards ?? 6, status: r.status)
    }

    /// The cards of the review: the lesson's due cards, else the course's.
    static func reviewCards(_ r: Review) async -> [FlashCard] {
        let own = r.materialId == nil ? [] : await CardsAPI.dueCards(materialId: r.materialId, limit: r.cards)
        guard own.isEmpty, let course = r.courseId else { return own }
        return await CardsAPI.dueCards(courseId: course, limit: r.cards)
    }

    /// Up to 3 questions of the lesson (weak topics first).
    static func reviewQuestions(_ r: Review) async -> Quiz? {
        guard let m = r.materialId, let q = await QuizAPI.sectionCheck(materialId: m, pageFrom: 0, pageTo: .max) else { return nil }
        return q.questions.isEmpty ? nil : Quiz(id: q.id, lang: q.lang, questions: Array(q.questions.prefix(3)))
    }

    /// "Sonra" moves the review to tomorrow; "done" closes it.
    static func setReview(_ id: String, done: Bool) async {
        if done {
            struct U: Encodable { let status: String; let done_at: String }
            _ = try? await supabase.from("review_sessions").update(U(status: "done", done_at: ISO8601DateFormatter().string(from: Date()))).eq("id", value: id).execute()
        } else {
            struct U: Encodable { let scheduled_for: String }
            let tomorrow = iso.string(from: Date().addingTimeInterval(86_400))
            _ = try? await supabase.from("review_sessions").update(U(scheduled_for: tomorrow)).eq("id", value: id).execute()
        }
    }
}
