import Foundation
import Supabase

/// The reader's page marks from the placement test and quiz results (table topic_progress, same as the web's
/// `studyMarks` in web/src/api/placement.ts): pages of a topic to study, a weak one or a known one.
enum StudyMarksAPI {
    enum State: String { case todo, weak, known }

    struct Mark: Equatable {
        let title: String
        let pageFrom: Int
        let pageTo: Int
        let state: State
    }

    /// The student's topic states on this lesson's pages; topics never tested are left out. Kept on the phone
    /// (OfflineStore), so the marks show without internet too.
    static func marks(materialId: String) async -> [Mark] {
        struct Progress: Decodable { let state: String }
        struct Row: Decodable { let title: String; let page_from: Int?; let page_to: Int?; let topic_progress: [Progress]? }
        let file = "study-\(materialId).json"
        let data: Data
        if let fresh = try? await supabase.from("material_topics").select("title, page_from, page_to, topic_progress(state)")
            .eq("material_id", value: materialId).order("sort_order").execute().data {
            data = fresh
            OfflineStore.write(fresh, file)
        } else if let kept = OfflineStore.read(file) {
            data = kept
        } else {
            return []
        }
        let rows = (try? JSONDecoder().decode([Row].self, from: data)) ?? []
        return rows.compactMap { r in
            guard let from = r.page_from, from > 0, let s = r.topic_progress?.first.flatMap({ State(rawValue: $0.state) }) else { return nil }
            return Mark(title: r.title, pageFrom: from, pageTo: max(from, r.page_to ?? from), state: s)
        }
    }

    /// The mark of a page range: the most urgent state of the topics on it (to study, then weak, then known).
    static func mark(_ marks: [Mark], from: Int, to: Int) -> Mark? {
        let rank: [State: Int] = [.todo: 0, .weak: 1, .known: 2]
        return marks.filter { $0.pageFrom <= to && $0.pageTo >= from }.min { rank[$0.state]! < rank[$1.state]! }
    }

    /// "PDF'te çalışman gereken sayfalar işaretlendi" is shown once per lesson (until closed on this device).
    static func noteSeen(_ materialId: String) -> Bool { UserDefaults.standard.bool(forKey: "kavis.studyNote.\(materialId)") }
    static func keepNoteSeen(_ materialId: String) { UserDefaults.standard.set(true, forKey: "kavis.studyNote.\(materialId)") }
}
