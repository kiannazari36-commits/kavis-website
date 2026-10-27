import Foundation
import Supabase

/// One class of the school timetable (`timetable_entries`), the same as the web (`web/src/api/timetable.ts`).
struct ClassEntry: Identifiable, Equatable {
    let id: String
    /// 1 = Monday … 7 = Sunday
    let weekday: Int
    let start: String
    let end: String?
    let title: String
    let room: String?
    let teacher: String?
    var remind: Bool
}

enum TimetableAPI {
    private struct Row: Decodable {
        let id: String
        let weekday: Int
        let start_time: String
        let end_time: String?
        let title: String
        let room, teacher: String?
        let remind: Bool
    }

    private static func hm(_ t: String) -> String { String(t.prefix(5)) }

    static func list() async -> [ClassEntry] {
        let rows: [Row] = (try? await supabase.from("timetable_entries")
            .select("id, weekday, start_time, end_time, title, room, teacher, remind")
            .order("weekday").order("start_time").execute().value) ?? []
        return rows.map { ClassEntry(id: $0.id, weekday: $0.weekday, start: hm($0.start_time), end: $0.end_time.map(hm), title: $0.title,
                                     room: $0.room, teacher: $0.teacher, remind: $0.remind) }
    }

    /// Adds a class typed by the student; false when it could not be saved.
    static func add(weekday: Int, start: String, end: String?, title: String, room: String, teacher: String) async -> Bool {
        guard let uid = supabase.auth.currentUser?.id else { return false }
        struct Insert: Encodable {
            let user_id: UUID
            let weekday: Int
            let start_time: String
            let end_time: String?
            let title: String
            let room, teacher: String?
        }
        let row = Insert(user_id: uid, weekday: weekday, start_time: start, end_time: end, title: title.trimmingCharacters(in: .whitespaces),
                         room: room.trimmingCharacters(in: .whitespaces).nilIfEmpty, teacher: teacher.trimmingCharacters(in: .whitespaces).nilIfEmpty)
        return (try? await supabase.from("timetable_entries").insert(row).execute()) != nil
    }

    static func setRemind(_ id: String, _ on: Bool) async {
        struct Update: Encodable { let remind: Bool }
        _ = try? await supabase.from("timetable_entries").update(Update(remind: on)).eq("id", value: id).execute()
    }

    static func delete(_ id: String) async {
        _ = try? await supabase.from("timetable_entries").delete().eq("id", value: id).execute()
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
