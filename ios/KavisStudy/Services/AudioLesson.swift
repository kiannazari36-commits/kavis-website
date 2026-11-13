import AVFoundation
import Foundation
import Supabase

/// "Sesli anlatım" (design NewIPad, assistant quick action "Önemli ve zayıf konularımı anlat"), the same as the web
/// (`web/src/audio/chapters.ts`, `AudioLesson.tsx`): up to 5 short parts of the lesson the student read last, weak
/// topics first, then what the lecturer stressed. The text is the lesson's review summary (Edge Function
/// lesson-summary, only facts from the PDF); here it is only grouped by topic, ordered and read aloud by the phone.

/// A topic of the lesson (`material_topics`).
struct AudioTopic: Decodable, Equatable {
    let id: String
    let title: String
    let page_from: Int?
    let page_to: Int?
    let importance: Int?
    let teacher_minutes: Double?
    let teacher_repeats: Int?
    let teacher_said_exam: Bool?
}

/// Why a part was chosen; the player turns it into "Zayıf · %38", "Hoca 9 dk durdu", …
enum ChapterTag: Equatable {
    case weak(Int?), exam, minutes(Int), repeats(Int), important, summary
}

struct AudioChapter: Equatable {
    let title: String
    let pageFrom: Int
    let pageTo: Int
    let tag: ChapterTag
    let sentences: [String]
}

enum AudioChapters {
    static let maxChapters = 5
    /// Reading speeds of the player, in the design's order (1,0× → 1,25× → 1,5× → 0,8×).
    static let speeds: [Double] = [1, 1.25, 1.5, 0.8]

    /// Short pieces for the voice, so a pause or a jump lands between sentences.
    static func sentences(_ text: String) -> [String] {
        text.replacingOccurrences(of: #"\n+|(?<=[.!?…؟])\s+"#, with: "\u{1F}", options: .regularExpression)
            .split(separator: "\u{1F}").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private static func overlaps(_ p: RecapPoint, _ t: AudioTopic) -> Bool {
        guard let from = t.page_from else { return false }
        return p.page_from <= (t.page_to ?? from) && p.page_to >= from
    }

    /// Groups the summary points by the lesson topic they belong to (by pages) and keeps the most useful 5.
    static func build(points: [RecapPoint], topics: [AudioTopic], weak: [LessonSummary.Weak]) -> [AudioChapter] {
        struct Group { var topic: AudioTopic?; var points: [RecapPoint] }
        var keys: [String] = []
        var groups: [String: Group] = [:]
        for p in points {
            let topic = topics.first { overlaps(p, $0) }
            let key = topic?.id ?? "p\(p.page_from)"
            if groups[key] == nil { keys.append(key); groups[key] = Group(topic: topic, points: []) }
            groups[key]?.points.append(p)
        }
        let mastery = Dictionary(weak.map { ($0.id, $0.mastery) }, uniquingKeysWith: { a, _ in a })

        let scored: [(chapter: AudioChapter, rank: Double, order: Int)] = keys.enumerated().map { order, key in
            let g = groups[key]!
            let t = g.topic
            let pageFrom = g.points.map(\.page_from).min() ?? 0
            let pageTo = g.points.map(\.page_to).max() ?? pageFrom
            let tag: ChapterTag
            let rank: Double
            if (t.map { mastery[$0.id] != nil } ?? false) || g.points.contains(where: { $0.weak == true }) {
                let m = t.flatMap { mastery[$0.id] }
                tag = .weak(m)
                rank = Double(m ?? 50) / 1000
            } else if t?.teacher_said_exam == true {
                tag = .exam; rank = 1
            } else if let m = t?.teacher_minutes, m >= 3 {
                tag = .minutes(Int(m.rounded())); rank = 2 - m / 1000
            } else if let r = t?.teacher_repeats, r >= 2 {
                tag = .repeats(r); rank = 3 - Double(r) / 1000
            } else if let i = t?.importance, i >= 2 {
                tag = .important; rank = 4 - Double(i) / 10
            } else {
                tag = .summary; rank = 5
            }
            let chapter = AudioChapter(title: t?.title ?? "", pageFrom: pageFrom, pageTo: pageTo, tag: tag,
                                       sentences: g.points.flatMap { sentences($0.text) })
            return (chapter, rank, order)
        }
        return scored.filter { !$0.chapter.sentences.isEmpty }
            .sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.order < $1.order }
            .prefix(maxChapters).map(\.chapter)
    }

    /// Rough reading time: about 14 letters a second at normal speed.
    static func seconds(_ chars: Int) -> Int { Int((Double(chars) / 14).rounded()) }
}

/// The player: keeps reading while the student moves between screens (the small player over every screen except the
/// assistant), until closed. Free: the phone's own voice reads the summary, which the server makes once per lesson (a new
/// one only when the weak topics changed; that uses one "generate" of the trial, never a question).
@MainActor @Observable
final class AudioLessonModel: NSObject, AVSpeechSynthesizerDelegate {
    struct Lesson: Equatable { let title: String; let lang: Lang; let chapters: [AudioChapter] }
    enum Failure { case noLesson, locked, budget, failed }

    private(set) var lesson: Lesson?
    private(set) var loading = false
    private(set) var playing = false
    /// Current part and sentence.
    private(set) var idx = 0
    private(set) var sent = 0
    private(set) var speedIdx = 0

    private let synth = AVSpeechSynthesizer()
    /// Each new read gets a number, so the end of an utterance that was cancelled does nothing.
    private var run = 0
    private var utterances: [ObjectIdentifier: (run: Int, idx: Int, sent: Int)] = [:]
    /// The voice of Settings (female / male, speed).
    private var female: Bool?
    private var baseRate: Float = 1
    /// Said once when the last part ends.
    var onDone: ((Int) -> Void)?

    override init() {
        super.init()
        synth.delegate = self
    }

    var speed: Double { AudioChapters.speeds[speedIdx] }

    private var chars: [Int] { lesson?.chapters.map { $0.sentences.reduce(0) { $0 + $1.count + 1 } } ?? [] }
    var total: Int { AudioChapters.seconds(chars.reduce(0, +)) }
    var elapsed: Int {
        guard let lesson, idx < lesson.chapters.count else { return total }
        let before = chars.prefix(idx).reduce(0, +)
        let within = lesson.chapters[idx].sentences.prefix(sent).reduce(0) { $0 + $1.count + 1 }
        return AudioChapters.seconds(before + within)
    }

    // MARK: Start

    /// Starts the lesson the student read last in this course (`courseId` nil = any course).
    func start(courseId: String?, appLang: Lang, rate: Double, female: Bool?) async -> Failure? {
        guard !loading else { return nil }
        guard let lessonId = await Self.lastRead(courseId: courseId) else { return .noLesson }
        halt()
        loading = true
        defer { loading = false }
        async let recapQ = SummaryAPI.recap(materialId: lessonId.id)
        async let dataQ = SummaryAPI.lessonData(materialId: lessonId.id, lang: appLang)
        async let topicsQ = Self.topics(materialId: lessonId.id)
        let (recap, data, topics) = await (recapQ, dataQ, topicsQ)
        switch recap {
        case .failure(let f): return f == .locked ? .locked : f == .budget ? .budget : .failed
        case .success(let r):
            let chapters = AudioChapters.build(points: r.points, topics: topics, weak: data.weak)
            guard !chapters.isEmpty else { return .failed }
            self.female = female
            baseRate = Float(rate)
            lesson = Lesson(title: lessonId.title, lang: r.lang, chapters: chapters)
            idx = 0; sent = 0
            playing = true
            say(from: 0, sent: 0)
            return nil
        }
    }

    /// The newest lesson read in the course (any course when nil); a course without reading yet gives its first PDF.
    private static func lastRead(courseId: String?) async -> (id: String, title: String)? {
        if CoursesAPI.lastCourses.isEmpty { _ = await CoursesAPI.listCourses() }
        let pdfs = CoursesAPI.lastCourses.filter { courseId == nil || $0.id == courseId }.flatMap(\.pdfs)
        struct Row: Decodable { let material_id: String }
        let seen: [Row] = (try? await supabase.from("reading_progress").select("material_id").order("updated_at", ascending: false).limit(200).execute().value) ?? []
        let pdf = seen.compactMap { r in pdfs.first { $0.id == r.material_id } }.first ?? pdfs.first
        return pdf.map { ($0.id, $0.title.tr) }
    }

    private static func topics(materialId: String) async -> [AudioTopic] {
        (try? await supabase.from("material_topics")
            .select("id, title, page_from, page_to, importance, teacher_minutes, teacher_repeats, teacher_said_exam")
            .eq("material_id", value: materialId).order("sort_order").execute().value) ?? []
    }

    // MARK: Speaking

    private func voice(for lang: Lang) -> AVSpeechSynthesisVoice? {
        let code = ["tr": "tr-TR", "en": "en-US", "fa": "fa-IR", "ar": "ar-SA"][lang.rawValue] ?? lang.rawValue
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == code }
        let wanted: AVSpeechSynthesisVoiceGender? = female.map { $0 ? .female : .male }
        return voices.first { wanted != nil && $0.gender == wanted } ?? AVSpeechSynthesisVoice(language: code)
    }

    /// Speaks the part from the sentence on; the next part follows by itself.
    private func say(from idx: Int, sent: Int) {
        guard let lesson, idx < lesson.chapters.count else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        run += 1
        synth.stopSpeaking(at: .immediate)
        utterances = [:]
        let chapter = lesson.chapters[idx]
        let voice = voice(for: lesson.lang)
        for (i, text) in chapter.sentences.enumerated().dropFirst(sent) {
            let u = AVSpeechUtterance(string: text)
            u.voice = voice
            u.rate = AVSpeechUtteranceDefaultSpeechRate * baseRate * Float(speed)
            utterances[ObjectIdentifier(u)] = (run, idx, i)
            synth.speak(u)
        }
    }

    private func halt() {
        run += 1
        utterances = [:]
        synth.stopSpeaking(at: .immediate)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let key = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self, let info = utterances[key], info.run == run else { return }
            idx = info.idx; sent = info.sent
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let key = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self, let lesson, let info = utterances[key], info.run == run,
                  info.sent == lesson.chapters[info.idx].sentences.count - 1 else { return }
            if info.idx + 1 < lesson.chapters.count {
                idx = info.idx + 1; sent = 0
                say(from: idx, sent: 0)
            } else {
                playing = false
                sent = lesson.chapters[info.idx].sentences.count
                onDone?(lesson.chapters.count)
            }
        }
    }

    // MARK: Controls

    func toggle() {
        guard lesson != nil else { return }
        if playing {
            synth.pauseSpeaking(at: .word)
            playing = false
        } else if synth.isPaused {
            synth.continueSpeaking()
            playing = true
        } else {
            playing = true
            say(from: min(idx, (lesson?.chapters.count ?? 1) - 1), sent: sent >= (lesson?.chapters[idx].sentences.count ?? 0) ? 0 : sent)
        }
    }

    func pick(_ i: Int) {
        guard let lesson, i >= 0, i < lesson.chapters.count else { return }
        idx = i; sent = 0
        playing = true
        say(from: i, sent: 0)
    }

    func prev() {
        // Past the first sentence of a part, "previous" goes back to its start (as a music player does).
        pick(sent > 0 ? idx : max(0, idx - 1))
    }

    func next() { pick(min(idx + 1, (lesson?.chapters.count ?? 1) - 1)) }

    func cycleSpeed() {
        speedIdx = (speedIdx + 1) % AudioChapters.speeds.count
        if playing { say(from: idx, sent: sent) } else if synth.isPaused { halt() }
    }

    func stop() {
        halt()
        playing = false
        lesson = nil
        idx = 0; sent = 0
    }
}
