import Foundation
import Supabase

/// A flash card (`flashcards`, made by the server from the lessons; the app only saves the review state).
struct FlashCard: Identifiable, Equatable {
    let id: String
    let q: String
    let a: String
    let note: String
    let page: Int?
    let deck: String
    /// The deck's language (the content language), not the app language.
    let lang: Lang
    var intervalDays: Double
    var ease: Double
    var reps: Int
    var againCount: Int

    /// A card from a test question keeps its A–E options after an empty line.
    var question: String { q.components(separatedBy: "\n\n").first ?? q }
    var options: String { q.components(separatedBy: "\n\n").dropFirst().joined(separator: "\n") }
}

enum CardRating: String { case again, hard, good }

/// Spaced repetition, the same rules as the web (`web/src/api/cards.ts`).
enum CardsAPI {
    /// Cards due now, cards on the student's weak topics first, then oldest first; optionally only one course's or one lesson's deck.
    static func dueCards(courseId: String? = nil, materialId: String? = nil, limit: Int = 30) async -> [FlashCard] {
        struct Deck: Decodable { let title: String?; let lang: String?; let material_id: String? }
        struct Topic: Decodable { let material_id: String; let page_from: Int?; let page_to: Int? }
        struct Weak: Decodable { let material_topics: Topic }
        struct Row: Decodable {
            let id, question, answer: String
            let note: String?
            let page: Int?
            let interval_days: Double
            let ease: Double
            let reps, again_count: Int
            let material_id: String?
            let card_decks: Deck
        }
        var q = supabase.from("flashcards")
            .select("id, question, answer, note, page, interval_days, ease, reps, again_count, material_id, card_decks!inner(title, lang, course_id, material_id)")
            .lte("due_at", value: ISO8601DateFormatter().string(from: Date()))
        if let materialId { q = q.eq("card_decks.material_id", value: materialId) } else if let courseId { q = q.eq("card_decks.course_id", value: courseId) }
        // Take more than needed, so weak-topic cards can move to the front before the cut.
        let rows: [Row] = (try? await q.order("due_at").limit(max(limit * 5, 150)).execute().value) ?? []
        // A card is on a weak topic when its page lies in the page range of a weak topic of the same lesson (mistake cards
        // carry their lesson in `material_id`, lesson cards in their deck). Same rule as the web.
        let weakRows: [Weak] = (try? await supabase.from("topic_progress").select("material_topics!inner(material_id, page_from, page_to)")
            .eq("state", value: "weak").execute().value) ?? []
        let weak = weakRows.map(\.material_topics)
        func onWeakTopic(_ r: Row) -> Bool {
            guard let page = r.page else { return false }
            let lesson = r.material_id ?? r.card_decks.material_id
            return weak.contains { t in
                guard t.material_id == lesson, let from = t.page_from else { return false }
                return page >= from && page <= (t.page_to ?? from)
            }
        }
        let sorted = rows.enumerated().sorted { a, b in
            let (wa, wb) = (onWeakTopic(a.element), onWeakTopic(b.element))
            return wa != wb ? wa : a.offset < b.offset
        }.map(\.element).prefix(limit)
        return sorted.map {
            FlashCard(id: $0.id, q: $0.question, a: $0.answer, note: $0.note ?? "", page: $0.page, deck: $0.card_decks.title ?? "",
                      lang: Lang(rawValue: $0.card_decks.lang ?? "") ?? .tr, intervalDays: $0.interval_days, ease: $0.ease,
                      reps: $0.reps, againCount: $0.again_count)
        }
    }

    /// Days until the card comes back when the student knew it (first time 4 days, as in the design).
    static func goodInterval(_ c: FlashCard) -> Int {
        c.reps == 0 ? 4 : Int((max(4, c.intervalDays) * c.ease).rounded())
    }

    /// Didn't know → 1 min, Hard → 10 min, Knew it → goodInterval days.
    static func rate(_ c: FlashCard, _ rating: CardRating, now: Date = Date()) async {
        let ease = max(1.3, c.ease + (rating == .again ? -0.2 : rating == .hard ? -0.15 : 0))
        let days = rating == .good ? Double(goodInterval(c)) : c.intervalDays
        let due = rating == .again ? now.addingTimeInterval(60) : rating == .hard ? now.addingTimeInterval(600) : now.addingTimeInterval(days * 86_400)
        let f = ISO8601DateFormatter()
        struct Update: Encodable {
            let due_at: String; let interval_days: Double; let ease: Double; let reps: Int; let again_count: Int
            let last_rating: String; let last_reviewed_at: String
        }
        _ = try? await supabase.from("flashcards").update(Update(
            due_at: f.string(from: due), interval_days: rating == .again ? 0 : days, ease: (ease * 100).rounded() / 100,
            reps: rating == .again ? 0 : c.reps + (rating == .good ? 1 : 0), again_count: c.againCount + (rating == .again ? 1 : 0),
            last_rating: rating.rawValue, last_reviewed_at: f.string(from: now)
        )).eq("id", value: c.id).execute()
    }
}
