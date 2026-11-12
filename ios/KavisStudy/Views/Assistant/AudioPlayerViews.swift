import SwiftUI

/// Design NewIPad "Sesli anlatım": the big player card on the assistant screen and the small player over the other
/// screens (tapping it goes back to the assistant).
private enum AudioText {
    static func tag(_ tag: ChapterTag, _ prefs: AppPrefs) -> String {
        let lang = prefs.lang
        switch tag {
        case .weak(let n): return n.map { prefs.t("auTagWeak", ["p": Format.percent($0, lang)]) } ?? prefs.t("auTagWeakNo")
        case .minutes(let n): return prefs.t("auTagMin", ["n": Format.num(n, lang)])
        case .repeats(let n): return prefs.t("auTagRep", ["n": Format.num(n, lang)])
        case .exam: return prefs.t("auTagExam")
        case .important: return prefs.t("auTagImp")
        case .summary: return prefs.t("auTagSum")
        }
    }

    static func time(_ seconds: Int, _ lang: Lang) -> String {
        Format.num(seconds / 60, lang) + ":" + (seconds % 60 < 10 ? Format.num(0, lang) : "") + Format.num(seconds % 60, lang)
    }
}

struct AudioCard: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AudioLessonModel.self) private var audio

    private var lang: Lang { prefs.lang }
    private func t(_ key: String) -> String { prefs.t(key) }

    var body: some View {
        if let lesson = audio.lesson {
            let chapters = lesson.chapters
            let current = chapters[min(audio.idx, chapters.count - 1)]
            let minutes = max(1, Int((Double(audio.total) / 60).rounded()))
            let pct = audio.total > 0 ? min(1, Double(audio.elapsed) / Double(audio.total)) : 0
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    KIcon(name: .headphones, size: 22, width: 1.8).foregroundStyle(KPhone.tile2Text)
                        .frame(width: 46, height: 46).background(KPhone.tile2, in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(t("auKicker")) · \(lesson.title.uppercased(with: lang.locale))").font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 0.8)
                            .foregroundStyle(KPhone.text2).lineLimit(1)
                        Text(t("auHead")).font(KFont.ui(18, .bold, lang: lang)).foregroundStyle(KPhone.text)
                        Text(prefs.t("auSub", ["n": Format.num(chapters.count, lang), "min": Format.num(minutes, lang)]))
                            .font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button { audio.stop() } label: {
                        KIcon(name: .close, size: 16, width: 2).foregroundStyle(KPhone.text2).frame(width: 36, height: 36)
                    }
                    .accessibilityLabel(t("auClose"))
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(chapters.enumerated()), id: \.offset) { i, c in
                            let on = i == audio.idx
                            Button { audio.pick(i) } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(c.title.isEmpty ? "\(t("pageAbbr")) \(Format.num(c.pageFrom, lang))" : c.title)
                                        .font(KFont.ui(13, .semibold, lang: lang)).lineLimit(1)
                                    Text(AudioText.tag(c.tag, prefs)).font(KFont.ui(11, lang: lang)).lineLimit(1)
                                        .foregroundStyle(on ? KPhone.ctaText.opacity(0.85) : c.tag == .exam || c.tag == .important || c.tag == .summary ? KPhone.text2 : KPhone.tile2Text)
                                }
                                .foregroundStyle(on ? KPhone.ctaText : KPhone.text)
                                .padding(.horizontal, 12).padding(.vertical, 9).frame(width: 150, alignment: .leading)
                                .background(on ? KPhone.cta : (i < audio.idx ? KPhone.sub : KPhone.seg), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
                Text(current.sentences.joined(separator: " ")).font(KFont.reading(15, lang: lesson.lang)).kLineHeight(1.55, size: 15, lang: lesson.lang)
                    .foregroundStyle(KPhone.text).environment(\.layoutDirection, lesson.lang.layoutDirection)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 10) {
                    Text(AudioText.time(audio.elapsed, lang)).font(KFont.mono(11, .regular)).foregroundStyle(KPhone.text2)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(KPhone.seg)
                            Capsule().fill(KPhone.cta).frame(width: g.size.width * pct)
                        }
                    }
                    .frame(height: 5)
                    Text(AudioText.time(audio.total, lang)).font(KFont.mono(11, .regular)).foregroundStyle(KPhone.text2)
                }
                .environment(\.layoutDirection, .leftToRight)
                HStack(spacing: 18) {
                    Spacer()
                    Button { audio.prev() } label: {
                        KIcon(name: .arrowRight, size: 20, width: 2, flipsInRTL: true).foregroundStyle(KPhone.text).rotationEffect(.degrees(180)).frame(width: 48, height: 48)
                            .background(KPhone.seg, in: Circle())
                    }
                    .accessibilityLabel(t("auPrev"))
                    Button { audio.toggle() } label: {
                        KIcon(name: audio.playing ? .pause : .play, size: 24, width: 2.4).foregroundStyle(KPhone.ctaText)
                            .frame(width: 62, height: 62).background(KPhone.cta, in: Circle())
                    }
                    .accessibilityLabel(t(audio.playing ? "auPause" : "auResume"))
                    Button { audio.next() } label: {
                        KIcon(name: .arrowRight, size: 20, width: 2, flipsInRTL: true).foregroundStyle(KPhone.text).frame(width: 48, height: 48)
                            .background(KPhone.seg, in: Circle())
                    }
                    .accessibilityLabel(t("auNext"))
                    Button { audio.cycleSpeed() } label: {
                        Text(Format.num(speedLabel, lang) + "×").font(KFont.mono(12, .semibold)).foregroundStyle(KPhone.text)
                            .frame(minWidth: 52, minHeight: 36).background(KPhone.seg, in: Capsule())
                    }
                    .accessibilityLabel(t("auSpeed"))
                    Spacer()
                }
                .environment(\.layoutDirection, .leftToRight)
                HStack(alignment: .top, spacing: 8) {
                    KIcon(name: .headphones, size: 15, width: 1.8).foregroundStyle(KPhone.text2)
                    Text("\(t("auKeepA")) **\(t("auKeepB"))**\(t("auKeepC"))").font(KFont.ui(12, lang: lang)).foregroundStyle(KPhone.text2)
                }
            }
            .padding(16)
            .background(KPhone.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(t("auName"))
        }
    }

    private var speedLabel: String {
        let s = AudioChapters.speeds[audio.speedIdx]
        let text = s == 1 ? "1.0" : String(s)
        return lang == .en ? text : text.replacingOccurrences(of: ".", with: ",")
    }
}

/// The small player over the other screens.
struct AudioMini: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(AudioLessonModel.self) private var audio

    private var lang: Lang { prefs.lang }

    var body: some View {
        if let lesson = audio.lesson {
            let current = lesson.chapters[min(audio.idx, lesson.chapters.count - 1)]
            let pct = audio.total > 0 ? min(1, Double(audio.elapsed) / Double(audio.total)) : 0
            HStack(spacing: 10) {
                Button { app.go(.assistant) } label: {
                    HStack(spacing: 10) {
                        KIcon(name: .headphones, size: 17, width: 1.8).foregroundStyle(KPhone.tile2Text)
                            .frame(width: 38, height: 38).background(KPhone.tile2, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(prefs.t(audio.playing ? "auPlaying" : "auPaused")) · \(AudioText.time(audio.elapsed, lang))")
                                .font(KFont.mono(9, .regular)).foregroundStyle(KPhone.text2)
                            Text("\(Format.num(audio.idx + 1, lang))/\(Format.num(lesson.chapters.count, lang)) · \(current.title.isEmpty ? lesson.title : current.title)")
                                .font(KFont.ui(13, .semibold, lang: lang)).foregroundStyle(KPhone.text).lineLimit(1)
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(KPhone.seg)
                                    Capsule().fill(KPhone.cta).frame(width: g.size.width * pct)
                                }
                            }
                            .frame(height: 3)
                            .environment(\.layoutDirection, .leftToRight)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(prefs.t("auOpen"))
                Button { audio.toggle() } label: {
                    KIcon(name: audio.playing ? .pause : .play, size: 16, width: 2.2).foregroundStyle(KPhone.ctaText)
                        .frame(width: 40, height: 40).background(KPhone.cta, in: Circle())
                }
                .accessibilityLabel(prefs.t(audio.playing ? "auPause" : "auResume"))
                Button { audio.stop() } label: {
                    KIcon(name: .close, size: 14, width: 2).foregroundStyle(KPhone.text2).frame(width: 34, height: 40)
                }
                .accessibilityLabel(prefs.t("auClose"))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(KPhone.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(KPhone.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
            .padding(.horizontal, 12)
            .frame(maxWidth: 520)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(prefs.t("auRegion"))
        }
    }
}
