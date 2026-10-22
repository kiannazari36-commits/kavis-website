import Foundation

/// A course (or "all my courses") the assistant can answer about. Mock data copied from the web (`mock-assistant.json`).
struct AssistantTopic: Decodable, Identifiable, Hashable {
    let id: String
    let name: L10n
    let sub: L10n
    /// Dot color as "#RRGGBB".
    let color: String
    let folder: String?
    let sample: Sample

    struct Sample: Decodable, Hashable {
        let q: L10n
        let a: L10n
        let src: L10n
    }

    var isAll: Bool { id == "all" }
}

/// A file the student adds in the assistant; the server guesses which course it belongs to.
struct AssistantAttachment: Decodable {
    let tag: L10n
    let name: L10n
    let meta: L10n
    let topic: String
    let why: L10n
}

enum AttachmentKind: String, CaseIterable { case pdf, photo, audio }

/// What the assistant says back.
struct AssistantReply: Equatable {
    var text: String
    /// Where in the student's material the answer comes from, as shown on the chip: "↗ SAYFA 14".
    var source: String?
    /// True when the answer is not from the student's PDFs (only possible with "AI + research").
    var outsidePDF = false
}

enum AssistantAPI {
    private struct Mock: Decodable {
        let topics: [AssistantTopic]
        let attachments: [String: AssistantAttachment]
    }

    private static let mock: Mock = MockData.load("mock-assistant")

    static func listTopics() async -> [AssistantTopic] {
        await fakeRequest(mock.topics, ms: 120)
    }

    static var topics: [AssistantTopic] { mock.topics }

    static func attachment(_ kind: AttachmentKind) async -> AssistantAttachment? {
        await fakeRequest(mock.attachments[kind.rawValue], ms: 300)
    }

    /// Words that point a question to one of the lesson's answers (the real assistant reads the PDF instead).
    private static let keywords: [(topic: String, words: [String])] = [
        ("hypertension", ["öksürük", "cough", "سرفه", "سعال"]),
        ("diabetes", ["metformin", "متفورمین", "ميتفورمين", "الميتفورمين"]),
        ("toxicology", ["antidot", "atropin", "atropine", "پادزهر", "ترياق"]),
    ]
    private static let pregnancy = ["gebelik", "pregnan", "حاملگی", "حمل", "الحمل"]
    private static let thiazide = ["tiyazid", "thiazide", "تیازید", "الثيازيد"]

    /// The mock assistant. It answers only from the lesson texts it knows (CLAUDE.md: only the student's material);
    /// what it does not know is said honestly. A real server will read the student's PDFs.
    static func ask(topicId: String, question: String, ai: Bool, lang: Lang) async -> AssistantReply {
        let q = question.lowercased()
        let reply = answer(topicId: topicId, question: q, ai: ai, lang: lang)
        return await fakeRequest(reply, ms: 700)
    }

    static func answer(topicId: String, question q: String, ai: Bool, lang: Lang) -> AssistantReply {
        let inHypertension = topicId == "hypertension" || topicId == "all"
        if inHypertension, pregnancy.contains(where: q.contains) {
            return AssistantReply(
                text: Strings.design("PDF'inde (s. 14) ACE inhibitörleri ve ARB'lerin gebelikte kontrendike olduğu yazıyor. Nedeni bu derste anlatılmamış; bu yüzden PDF dışından bilgi eklemiyorum.", lang),
                source: Strings.design("↗ SAYFA 14", lang))
        }
        if inHypertension, thiazide.contains(where: q.contains) {
            return AssistantReply(
                text: Strings.design("Gut öyküsü olan hastalarda. Tiyazidler serum ürik asit düzeyini artırır", lang) + ".",
                source: Strings.design("↗ SAYFA 14", lang))
        }
        for (topic, words) in keywords where (topicId == topic || topicId == "all") && words.contains(where: q.contains) {
            if let t = mock.topics.first(where: { $0.id == topic }) { return AssistantReply(text: t.sample.a[lang], source: "↗ \(t.sample.src[lang])") }
        }
        return AssistantReply(text: notFound(ai: ai, lang: lang), source: nil, outsidePDF: false)
    }

    /// Honest answer when nothing in the student's material matches.
    private static func notFound(ai: Bool, lang: Lang) -> String {
        if ai { return Strings.text("k165", lang) } // "AI + research" needs the server
        switch lang {
        case .tr: return "Bunu senin PDF'lerinde bulamadım. Materyalinin dışına çıkmak istersen \"Yapay zekâ + araştırma\" seçeneğini aç."
        case .en: return "I couldn't find this in your PDFs. Turn on \"AI + research\" if you want me to go beyond your material."
        case .fa: return "این را در PDFهای تو پیدا نکردم. اگر می‌خواهی از مطالبت فراتر بروم، «هوش مصنوعی + پژوهش» را روشن کن."
        case .ar: return "لم أجد هذا في ملفات PDF الخاصة بك. فعّل «الذكاء الاصطناعي + البحث» إن أردت أن أتجاوز موادك."
        }
    }
}
