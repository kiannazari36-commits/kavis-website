import AVFoundation
import SwiftUI

/// Plays the recording's sound (signed link from the server) and reports where it is.
@Observable
final class LecturePlayer {
    private var player: AVPlayer?
    private(set) var now: Double = 0
    private(set) var playing = false
    var speed: Float = 1 { didSet { if playing { player?.rate = speed } } }
    var hasSound: Bool { player != nil }

    func load(_ url: URL?, at start: Double) {
        guard let url, player == nil else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        player = AVPlayer(url: url)
        if start > 0 { seek(start, play: false) }
    }

    func toggle() {
        guard let player else { return }
        if playing { player.pause() } else { try? AVAudioSession.sharedInstance().setActive(true); player.playImmediately(atRate: speed) }
        playing.toggle()
    }

    func seek(_ sec: Double, play: Bool = true) {
        guard let player else { return }
        player.seek(to: CMTime(seconds: sec, preferredTimescale: 600))
        now = sec
        if play, !playing { toggle() }
    }

    /// Follows the sound while the page is open (the current line is highlighted).
    func follow() async {
        while !Task.isCancelled {
            if let player {
                now = player.currentTime().seconds.isFinite ? player.currentTime().seconds : now
                if playing, player.rate == 0, player.currentItem?.status == .readyToPlay,
                   let end = player.currentItem?.duration.seconds, end.isFinite, now >= end - 0.5 { playing = false }
            }
            try? await Task.sleep(for: .milliseconds(300))
        }
    }

    func stop() {
        player?.pause()
        playing = false
    }
}

/// Design: design/ScrAudio.dc.html ("Ders ses kaydı"), with the web's /recording page as the data model: the player,
/// two tabs "Metin" (the whole talk with times; each part shows its PDF page, the moments the lecturer stressed are
/// marked) and "Hocanın vurguları" (stressed moments, time per topic, exam on those topics). Tapping a line plays the
/// sound from there; the page tag opens the reader at that page. While the server is still matching the text with the
/// PDF, the page asks again every 4 seconds.
struct RecordingView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast

    let recordingId: String
    /// Opened from a note on a PDF page: start at that moment (seconds).
    var startAt: Double = 0

    @State private var rec: RecordingAPI.Recording?
    @State private var loaded = false
    @State private var emphasis = MockFlag.value("tab") == "emphasis"
    @State private var player = LecturePlayer()

    private var lang: Lang { prefs.lang }
    private func t(_ key: String) -> String { prefs.t(key) }

    private enum C {
        static let bg = Color.pair(0xF4EFE6, 0x15120F)
        static let card = Color.pair(0xFFFCF6, 0x211C18)
        static let sub = Color.pair(0xF1EBE0, 0x2B2520)
        static let seg = Color.pair(0xFFFCF6, 0x463D35)
        static let text2 = Color.pair(0x6E645A, 0xBDB2A4)
        static let text3 = Color.pair(0x776C60, 0x9A8F82)
        static let line = Color.pair(0xE6DDCF, 0x3A322B)
        static let pri = Color.pair(0x9C2F3A, 0xB23A47)
        static let priText = Color.pair(0x9C2F3A, 0xF09AA3)
        static let priSoft = Color.pair(0xF7E7E9, 0x3A2027)
        static let amb = Color(hex: 0xF2B33D)
        static let ambText = Color.pair(0x83560A, 0xF2C46E)
        static let ambSoft = Color.pair(0xFDF1D6, 0x3A2F1A)
        static let bad = Color.pair(0xC0352B, 0xF27A70)
        static let badSoft = Color.pair(0xFCE8E6, 0x3D1F1F)
        static let heat0 = Color.pair(0xE4E8ED, 0x2A3340)
    }

    var body: some View {
        ZStack {
            C.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if let rec {
                    ScrollView {
                        VStack(spacing: 12) {
                            if rec.working { note(t("rec_matching"), bg: C.ambSoft, fg: KPhone.text) }
                            if rec.status == "failed" { note(t("rec_failed"), bg: C.badSoft, fg: C.bad) }
                            playerCard(rec)
                            tabBar
                            if emphasis { emphasisTab(rec) } else { transcript(rec) }
                        }
                        .padding(.horizontal, 16).padding(.bottom, 24)
                    }
                } else if loaded {
                    Text(t("noResults")).font(KFont.ui(14, lang: lang)).foregroundStyle(C.text2).padding(.top, 40)
                    Spacer()
                } else {
                    Spacer()
                }
            }
        }
        .task(id: recordingId) {
            // Again every 4 seconds while the server is still matching.
            while !Task.isCancelled {
                let r = await RecordingAPI.getRecording(recordingId)
                rec = r
                loaded = true
                player.load(r?.audioURL, at: startAt)
                guard r?.working == true else { return }
                try? await Task.sleep(for: .seconds(4))
            }
        }
        .task { await player.follow() }
        .onDisappear { player.stop() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 4) {
            Button { app.back() } label: {
                KIcon(name: .chevronLeft, size: 24, width: 1.8, flipsInRTL: true).foregroundStyle(KPhone.text).frame(width: 44, height: 44)
            }
            .accessibilityLabel(t("back"))
            VStack(alignment: .leading, spacing: 1) {
                Text(t("rec_page")).font(KFont.ui(19, .bold, lang: lang)).foregroundStyle(KPhone.text)
                if let rec {
                    Text([rec.pdf?.title ?? "", Format.clock(rec.seconds)].filter { !$0.isEmpty }.joined(separator: " · ").uppercased(with: lang.locale))
                        .font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 0.6).foregroundStyle(C.text3).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 6).padding(.trailing, 12).frame(height: 48)
        .padding(.top, KLayout.top(54, minimum: 6))
        .padding(.bottom, 6)
    }

    private func note(_ text: String, bg: Color, fg: Color) -> some View {
        Text(text).font(KFont.ui(13, lang: lang)).kLineHeight(1.45, size: 13, lang: lang).foregroundStyle(fg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Player

    private func playerCard(_ rec: RecordingAPI.Recording) -> some View {
        let total = Double(max(1, rec.seconds))
        return VStack(alignment: .leading, spacing: 10) {
            if player.hasSound {
                HStack(spacing: 12) {
                    Button { player.toggle() } label: {
                        KIcon(name: player.playing ? .pause : .play, size: 18, width: 2.4)
                            .foregroundStyle(Color(hex: 0xFFFCF6))
                            .frame(width: 48, height: 48).background(C.pri, in: Circle())
                    }
                    .accessibilityLabel(prefs.d(player.playing ? "Durdur" : "Oynat"))
                    VStack(spacing: 6) {
                        // Where the sound is; tap to jump.
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(C.line)
                                Capsule().fill(C.pri).frame(width: g.size.width * min(1, player.now / total))
                            }
                            .contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0).onEnded { v in
                                let x = lang.isRTL ? g.size.width - v.location.x : v.location.x
                                player.seek(max(0, min(1, x / g.size.width)) * total)
                            })
                        }
                        .frame(height: 8)
                        heatBar(rec, total: total)
                    }
                    .environment(\.layoutDirection, .leftToRight)
                }
                HStack(spacing: 8) {
                    Text("\(Format.clock(Int(player.now))) / \(Format.clock(rec.seconds))").font(KFont.mono(11, .regular)).foregroundStyle(C.text2)
                    Spacer()
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(C.amb).frame(width: 10, height: 6)
                        Text(t("rec_stressed")).font(KFont.ui(11, lang: lang)).foregroundStyle(C.text2)
                    }
                    Button {
                        let all: [Float] = [1, 1.25, 1.5, 2]
                        player.speed = all[((all.firstIndex(of: player.speed) ?? 0) + 1) % all.count]
                    } label: {
                        Text("\(speedLabel)×")
                            .font(KFont.mono(11, .regular)).foregroundStyle(C.text2)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(C.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text(t("rec_textOnly")).font(KFont.ui(13, lang: lang)).kLineHeight(1.45, size: 13, lang: lang).foregroundStyle(C.text2)
            }
        }
        .padding(14)
        .background(C.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// Thin bar under the player: parts where the lecturer stressed something are amber.
    private func heatBar(_ rec: RecordingAPI.Recording, total: Double) -> some View {
        let hot = rec.quotes.map(\.at)
        let parts = rec.parts.isEmpty ? [RecordingAPI.Part(start: 0, end: total, page: 0, topic_id: nil)] : rec.parts
        return GeometryReader { g in
            HStack(spacing: 0) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, p in
                    Rectangle().fill(hot.contains { $0 >= p.start && $0 < p.end } ? C.amb : C.heat0)
                        .frame(width: max(0, g.size.width * (p.end - p.start) / total))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 6)
        .clipShape(Capsule())
        .accessibilityLabel(t("rec_time"))
    }

    // MARK: Tabs

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach([false, true], id: \.self) { e in
                let on = e == emphasis
                Button { emphasis = e } label: {
                    Text(t(e ? "rec_stress" : "rec_text"))
                        .font(KFont.ui(13, on ? .semibold : .regular, lang: lang))
                        .foregroundStyle(on ? KPhone.text : C.text2)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(on ? C.seg : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: on ? Color.black.opacity(0.08) : .clear, radius: 2, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(4)
        .background(C.sub, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// "1,0" / "1,25" / "1,5" / "2,0" (the design shows "1,0×").
    private var speedLabel: String {
        let s = player.speed == 1.25 ? "1.25" : String(format: "%.1f", player.speed)
        return Format.num(lang == .en ? s : s.replacingOccurrences(of: ".", with: ","), lang)
    }

    private func seek(_ sec: Double) {
        guard player.hasSound else { return toast.show(t("rec_noSound")) }
        player.seek(sec)
    }

    private func openPage(_ rec: RecordingAPI.Recording, _ page: Int) {
        guard let pdf = rec.pdf else { return app.go(.courses) }
        player.stop()
        app.readerPage = page > 0 ? page : nil
        app.go(.reader(pdf.id))
    }

    private func pageTag(_ page: Int) -> some View {
        Text(t("rec_pdfPage").replacingOccurrences(of: "{n}", with: Format.num(page, lang)))
            .font(KFont.mono(10, .regular)).foregroundStyle(C.text2)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(C.sub, in: RoundedRectangle(cornerRadius: 5))
    }

    private func hotTag(_ exam: Bool) -> some View {
        Text(t(exam ? "rec_saidExam" : "rec_stressed"))
            .font(KFont.ui(11, .semibold, lang: lang))
            .foregroundStyle(exam ? C.priText : Color(hex: 0x2A2420))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(exam ? C.priSoft : C.amb, in: RoundedRectangle(cornerRadius: 5))
    }

    // MARK: "Metin"

    /// The stressed moment said in line `i`: the line that contains the lecturer's words, else the line at its time.
    private func quoteOf(_ rec: RecordingAPI.Recording, _ i: Int) -> RecordingAPI.Quote? {
        func key(_ s: String) -> String { String(s.lowercased().filter { $0.isLetter || $0.isNumber }) }
        let lines = rec.segments.map { key($0.text) }
        return rec.quotes.first { q in
            let words = String(key(q.text).prefix(24))
            if !words.isEmpty, let hit = lines.firstIndex(where: { $0.contains(words) }) { return hit == i }
            let x = rec.segments[i]
            return q.at >= x.start && q.at < max(x.end, x.start + 1)
        }
    }

    private func transcript(_ rec: RecordingAPI.Recording) -> some View {
        let textLang = Lang(rawValue: rec.pdf?.language ?? "") ?? lang
        return LazyVStack(spacing: 10) {
            ForEach(Array(rec.segments.enumerated()), id: \.offset) { i, x in
                let page = rec.page(at: x.start)
                let newPage = page > 0 && page != (i > 0 ? rec.page(at: rec.segments[i - 1].start) : 0)
                let quote = quoteOf(rec, i)
                let on = player.now > 0 && player.now >= x.start && player.now < x.end
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(Format.clock(Int(x.start))).font(KFont.mono(11, .semibold)).foregroundStyle(C.priText)
                        if newPage {
                            Button { openPage(rec, page) } label: { pageTag(page) }.buttonStyle(.plain)
                        }
                        if let quote { hotTag(quote.kind == "exam") }
                        Spacer(minLength: 0)
                    }
                    Text(x.text).font(KFont.reading(15, lang: textLang)).kLineHeight(1.6, size: 15, lang: textLang)
                        .foregroundStyle(KPhone.text).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(on ? C.ambSoft : C.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(quote != nil ? C.amb : C.line, lineWidth: quote != nil ? 2 : 1))
                .contentShape(Rectangle())
                .onTapGesture { seek(x.start) }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    // MARK: "Hocanın vurguları"

    private func emphasisTab(_ rec: RecordingAPI.Recording) -> some View {
        let maxMin = max(1, rec.topics.map(\.minutes).max() ?? 1)
        return VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                KIcon(name: .mic, size: 20, width: 1.8).foregroundStyle(C.ambText)
                Text(t("rec_note")).font(KFont.ui(12, lang: lang)).kLineHeight(1.5, size: 12, lang: lang).foregroundStyle(KPhone.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(C.ambSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if !rec.quotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("rec_stress")).font(KFont.ui(16, .bold, lang: lang)).foregroundStyle(KPhone.text)
                    ForEach(Array(rec.quotes.enumerated()), id: \.offset) { _, q in
                        Button { seek(q.at) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    hotTag(q.kind == "exam")
                                    Spacer()
                                    Text(Format.clock(Int(q.at))).font(KFont.mono(11, .regular)).foregroundStyle(C.text2)
                                }
                                Text("“\(q.text)”").font(KFont.reading(14.5, lang: lang)).kLineHeight(1.5, size: 14.5, lang: lang)
                                    .foregroundStyle(KPhone.text).frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(C.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(C.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(C.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if !rec.topics.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("rec_time")).font(KFont.ui(16, .bold, lang: lang)).foregroundStyle(KPhone.text).padding(.bottom, 6)
                    ForEach(Array(rec.topics.enumerated()), id: \.element.id) { i, k in
                        let page = rec.parts.first { $0.topic_id == k.topic_id && $0.page > 0 }?.page ?? 0
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(Format.num(i + 1, lang)).font(KFont.mono(11, .regular)).foregroundStyle(C.text3).frame(width: 14, alignment: .leading)
                                Text(k.title).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.text).frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(Format.num(Int(k.minutes.rounded()), lang))\(t("rec_min"))").font(KFont.mono(12, .semibold)).foregroundStyle(i == 0 ? C.ambText : C.text2)
                            }
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(C.sub)
                                    Capsule().fill(k.said_exam ? C.pri : C.amb).frame(width: g.size.width * k.minutes / maxMin)
                                }
                            }
                            .frame(height: 8).padding(.leading, 22)
                            HStack(spacing: 6) {
                                if page > 0 { Button { openPage(rec, page) } label: { pageTag(page) }.buttonStyle(.plain) }
                                if k.said_exam {
                                    Text(t("rec_saidExam")).font(KFont.ui(10, .semibold, lang: lang)).foregroundStyle(C.bad)
                                        .padding(.horizontal, 7).padding(.vertical, 3).background(C.badSoft, in: RoundedRectangle(cornerRadius: 5))
                                }
                                if k.repeats > 1 {
                                    Text("\(Format.num(k.repeats, lang))\(t("rec_repeats"))").font(KFont.ui(10, .semibold, lang: lang)).foregroundStyle(C.ambText)
                                        .padding(.horizontal, 7).padding(.vertical, 3).background(C.ambSoft, in: RoundedRectangle(cornerRadius: 5))
                                }
                            }
                            .padding(.leading, 22)
                        }
                        .padding(.top, 10).padding(.bottom, 6)
                        .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1) }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(C.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if let pdf = rec.pdf, !rec.topics.isEmpty {
                Button {
                    player.stop()
                    app.go(.quiz(QuizTarget(materialId: pdf.id, kind: .final)))
                } label: {
                    Text(t("rec_examBtn")).font(KFont.ui(15, .semibold, lang: lang)).foregroundStyle(Color(hex: 0xFFFCF6))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(C.pri, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }
}
