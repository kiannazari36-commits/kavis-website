import Foundation
import Supabase

/// One notification written by the server (daily planner, lesson processing, grading, weekly report).
struct Notice: Identifiable, Equatable {
    let id: String
    let kind: String
    let title: String
    let body: String
    /// The web path the server put in `data.to` ("/plan", "/review?id=…"); see `route`.
    let to: String?
    let at: Date
    var read: Bool

    /// Where tapping it goes on the phone (the same targets as the web).
    var route: Route? {
        guard let to else { return nil }
        let parts = to.split(separator: "?", maxSplits: 1).map(String.init)
        let path = parts[0]
        let query = parts.count > 1 ? parts[1] : ""
        let id = query.split(separator: "&").compactMap { $0.hasPrefix("id=") ? String($0.dropFirst(3)) : nil }.first
        switch path {
        case "/review": return id.map { .review($0) }
        case "/plan": return .weekPlan
        case "/progress": return .progress
        case "/courses": return .courses
        case "/cards": return .cards(nil)
        case "/exam": return .examCenter
        case "/settings": return .settings
        default:
            if path.hasPrefix("/reader/") { return .reader(String(path.dropFirst("/reader/".count))) }
            return nil
        }
    }
}

/// Notifications, the same as the web (`web/src/api/notifications.ts`). The server writes them; the phone reads them
/// and marks them read.
enum NotificationsAPI {
    private struct Row: Decodable {
        let id, kind, title: String
        let body: String?
        let data: Data?
        let send_at: String
        let read_at: String?
        struct Data: Decodable { let to: String? }
    }

    private static func parse(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    private static func now() -> String { ISO8601DateFormatter().string(from: Date()) }

    /// Sent notifications, newest first (a snoozed one comes back when the snooze ends).
    static func list() async -> [Notice] {
        let n = now()
        let rows: [Row] = (try? await supabase.from("notifications")
            .select("id, kind, title, body, data, send_at, read_at")
            .lte("send_at", value: n)
            .or("snoozed_until.is.null,snoozed_until.lte.\(n)")
            .order("send_at", ascending: false)
            .limit(50)
            .execute().value) ?? []
        return rows.compactMap { r in
            guard let at = parse(r.send_at) else { return nil }
            return Notice(id: r.id, kind: r.kind, title: r.title, body: r.body ?? "", to: r.data?.to, at: at, read: r.read_at != nil)
        }
    }

    /// Any unread notification? (the dot on the bell)
    static func hasUnread() async -> Bool {
        let res = try? await supabase.from("notifications")
            .select("id", head: true, count: .exact)
            .is("read_at", value: nil)
            .lte("send_at", value: now())
            .execute()
        return (res?.count ?? 0) > 0
    }

    static func markAllRead() async {
        struct Update: Encodable { let read_at: String }
        _ = try? await supabase.from("notifications").update(Update(read_at: now())).is("read_at", value: nil).execute()
    }
}
