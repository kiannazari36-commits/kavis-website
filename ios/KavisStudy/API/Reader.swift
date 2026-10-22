import Foundation

/// The reading page of a lesson. The teacher's text is never changed (CLAUDE.md); only labels and explanations are added.
/// Mock data copied from the web (`mock-reader.json`).
struct ReaderDoc: Decodable, Identifiable {
    let id: String
    /// Language of the teacher's PDF; the text stays in this language.
    let language: String
    let title: String
    let course: String
    let pages: Int
    let page: Int
    let sections: [ReaderSection]
    let terms: [String: TermInfo]
    let sampleSentence: String
    let sampleTranslations: [String: SampleTranslation]

    var docLang: Lang { Lang(rawValue: language) ?? .tr }

    struct TermInfo: Decodable { let page: Int; let en: String }

    struct SampleTranslation: Decodable {
        let l: String
        let dir: String
        let lit: String
        let nat: String
    }
}

struct ReaderSection: Decodable, Identifiable {
    /// Tab title as written in the PDF ("2 · İlaç tedavisi").
    let tab: String
    let blocks: [ReaderBlock]
    /// Key in the reader texts for the "section finished" line.
    let end: String

    var id: String { tab }
}

struct ReaderBlock: Decodable, Identifiable {
    /// Keys in the reader texts for the page label and the tag.
    let page: String
    let tag: String
    let tagStyle: String
    let heading: String?
    let paragraphs: [Paragraph]
    let molecule: Bool?
    let audio: Bool?

    var id: String { page }
}

/// A paragraph is a list of segments, or one sentence the student can select.
enum Paragraph: Decodable {
    case segments([Segment])
    case selectable(String)

    private struct Selectable: Decodable { let selectable: Bool; let text: String }

    init(from decoder: Decoder) throws {
        if let s = try? decoder.singleValueContainer().decode(Selectable.self) {
            self = .selectable(s.text)
        } else {
            self = .segments(try decoder.singleValueContainer().decode([Segment].self))
        }
    }

    /// Plain text (for reading aloud).
    var plain: String {
        switch self {
        case .selectable(let text): text
        case .segments(let parts): parts.map(\.text).joined()
        }
    }
}

/// Plain text, or a hard word that opens an explanation.
enum Segment: Decodable {
    case text(String)
    case term(id: String, text: String)

    private struct Term: Decodable { let term: String; let text: String }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .text(s) } else {
            let t = try c.decode(Term.self)
            self = .term(id: t.term, text: t.text)
        }
    }

    var text: String {
        switch self {
        case .text(let s): s
        case .term(_, let t): t
        }
    }
}

enum ReaderAPI {
    private static let hypertension: ReaderDoc = MockData.load("mock-reader")

    static func getDoc(id: String) async -> ReaderDoc? {
        await fakeRequest(id == hypertension.id ? hypertension : nil, ms: 150)
    }
}
