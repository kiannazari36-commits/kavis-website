import SwiftUI

/// Design: design/ScrAssistant.dc.html (chat). The assistant answers only from the student's material; what it does
/// not find in the lesson it says so. Answers come from the server (Edge Function "assistant", like the web) and
/// appear while they are written; the conversation is kept. Voice, teach-back and "easy explanation" come later.
struct AssistantChatView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast
    @Environment(TrialModel.self) private var trial
    @Environment(NetworkMonitor.self) private var network

    let target: AssistantChatTarget

    @State private var messages: [ChatMessage] = []
    /// The answer while the server writes it ("" = thinking, nothing written yet).
    @State private var streaming: String?
    @State private var threadId: String?
    @State private var draft = ""
    @State private var waiting = false
    @State private var listening = false
    @State private var femaleVoice = true
    @State private var speedIndex = 1
    @State private var speaker = Speaker()
    @State private var started = false
    @FocusState private var focused: Bool

    private static let speeds: [Double] = [0.8, 1.0, 1.25, 1.5]

    private var lang: Lang { prefs.lang }
    private func d(_ turkish: String) -> String { prefs.d(turkish) }
    private var isAll: Bool { target.topicId == "all" }
    private var course: Course? { CoursesAPI.lastCourses.first { $0.id == target.topicId } }
    private var offline: Bool { !network.isOnline }

    var body: some View {
        ZStack(alignment: .bottom) {
            KPhone.authBg.ignoresSafeArea()
            Color.black.opacity(0.35).ignoresSafeArea()
            sheet
                .padding(.top, KLayout.top(64, minimum: 10))
        }
        .task {
            guard !started else { return }
            started = true
            let thread = await AssistantAPI.latestThread(courseId: isAll ? nil : target.topicId)
            threadId = thread.id
            messages = [ChatMessage(role: .assistant, text: welcome)] + thread.messages
            if !target.question.isEmpty { await ask(target.question) }
        }
        .onDisappear { speaker.stop() }
    }

    // MARK: Sheet

    private var sheet: some View {
        VStack(spacing: 0) {
            Capsule().fill(KPhone.line).frame(width: 40, height: 5).padding(.top, 8)
            header
            controls
            messagesList
            composer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Only the sheet's background reaches the bottom edge; the composer stays above the keyboard.
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                .fill(Color.pair(0xFFFCF6, 0x211C18))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var sourceLabel: String {
        let name = isAll ? d("Tüm derslerim") : (course?.name[lang] ?? "")
        return "\(d("KAYNAK ·")) \(name)"
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("StarButton").resizable().scaledToFit().frame(width: 30, height: 30)
                .frame(width: 34, height: 34).background(Circle().fill(Color(hex: 0x9C2F3A)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(d("Asistan")).font(KFont.ui(18, .bold, lang: lang)).foregroundStyle(KPhone.text)
                    .accessibilityAddTraits(.isHeader)
                Text(sourceLabel).font(KFont.mono(10, .regular)).tracking(lang.isRTL ? 0 : 0.5).foregroundStyle(KOnb.text3).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { app.back(fallback: .assistant) } label: {
                KIcon(name: .close, size: 16, width: 2).foregroundStyle(KPhone.text2)
                    .frame(width: 36, height: 36).background(KPhone.sub, in: Circle())
            }
            .accessibilityLabel(d("Kapat"))
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 8)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                listening.toggle()
                toast.show(prefs.t("k165")) // speech recognition comes later
            } label: {
                HStack(spacing: 8) {
                    ZStack(alignment: listening ? .trailing : .leading) {
                        Capsule().fill(listening ? KOnb.pri : KPhone.seg)
                        Circle().fill(.white).frame(width: 20, height: 20).shadow(color: .black.opacity(0.2), radius: 1.5, y: 1).padding(2)
                    }
                    .frame(width: 44, height: 24)
                    Text(d("Sürekli dinle")).font(KFont.ui(13, .medium, lang: lang)).foregroundStyle(KPhone.text)
                }
                .frame(minHeight: 44)
            }
            .accessibilityAddTraits(listening ? .isSelected : [])
            Spacer()
            Button { femaleVoice.toggle() } label: {
                HStack(spacing: 5) {
                    KIcon(name: .speaker, size: 14, width: 1.8)
                    Text(femaleVoice ? d("Kadın sesi") : Self.maleVoiceLabel(lang)).font(KFont.ui(12, .medium, lang: lang))
                }
                .foregroundStyle(KPhone.text2)
                .padding(.horizontal, 10).frame(height: 32)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(KPhone.line, lineWidth: 1))
            }
            Button { speedIndex = (speedIndex + 1) % Self.speeds.count } label: {
                Text(speedLabel).font(KFont.mono(12, .regular)).foregroundStyle(KPhone.text2)
                    .padding(.horizontal, 10).frame(height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(KPhone.line, lineWidth: 1))
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 4)
        .overlay(alignment: .bottom) { Rectangle().fill(KPhone.line).frame(height: 1) }
    }

    private var speedLabel: String {
        let v = Self.speeds[speedIndex]
        let text = v == v.rounded() ? String(format: "%.1f", v) : String(format: "%g", v)
        return (lang == .tr ? text.replacingOccurrences(of: ".", with: ",") : text) + "×"
    }

    private static func maleVoiceLabel(_ lang: Lang) -> String {
        switch lang {
        case .tr: "Erkek sesi"
        case .en: "Male voice"
        case .fa: "صدای مرد"
        case .ar: "صوت رجل"
        }
    }

    // MARK: Messages

    /// The design's greeting with the student's course ("Merhaba! Yalnızca “Farmakoloji” PDF'ine dayanarak cevap veriyorum.").
    private var welcome: String {
        if isAll { return d("Merhaba! Tüm derslerindeki PDF, ses kaydı ve sınav sonuçlarına bakarak cevap veriyorum.") }
        var text = d("Merhaba! Yalnızca “Hipertansiyon” PDF'ine dayanarak cevap veriyorum. Şu an sayfa 12'desin.")
        // The page remark belongs to the reader; here only the first sentence, with the course name.
        if let open = text.firstIndex(where: { "“«\"".contains($0) }), let close = text[text.index(after: open)...].firstIndex(where: { "”»\"".contains($0) }) {
            text.replaceSubrange(text.index(after: open)..<close, with: course?.name[lang] ?? "")
        }
        if let end = text.range(of: ". ") { text = String(text[..<end.lowerBound]) + "." }
        return text
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    if offline { offlineBanner }
                    ForEach(messages) { message in bubble(message).id(message.id) }
                    if let streaming {
                        Group {
                            if streaming.isEmpty {
                                Text(prefs.t("thinking")).font(KFont.ui(13, lang: lang)).foregroundStyle(KOnb.text3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                bubble(ChatMessage(role: .assistant, text: streaming))
                            }
                        }
                        .id("typing")
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                withAnimation { proxy.scrollTo(waiting ? "typing" : (messages.last?.id ?? "typing"), anchor: .bottom) }
            }
            .onChange(of: waiting) { _, _ in
                withAnimation { proxy.scrollTo(waiting ? "typing" : (messages.last?.id ?? "typing"), anchor: .bottom) }
            }
            .onChange(of: streaming) { _, _ in proxy.scrollTo("typing", anchor: .bottom) }
        }
    }

    private func bubble(_ message: ChatMessage) -> some View {
        let mine = message.role == .user
        return VStack(alignment: mine ? .trailing : .leading, spacing: 6) {
            Text(message.text)
                .font(KFont.ui(14, lang: lang)).kLineHeight(1.55, size: 14, lang: lang)
                .foregroundStyle(mine ? KPhone.ctaText : KPhone.text)
                .padding(.horizontal, 14).padding(.vertical, mine ? 10 : 12)
                .background(mine ? KOnb.pri : KPhone.sub,
                            in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: mine ? 18 : 6,
                                                       bottomTrailingRadius: mine ? 6 : 18, topTrailingRadius: 18, style: .continuous))
                .frame(maxWidth: mine ? 300 : 340, alignment: mine ? .trailing : .leading)
                .onTapGesture { if !mine { speak(message.text) } }
                .accessibilityHint(mine ? "" : d("Dinle"))
            if !mine { extras(message) }
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }

    /// Where the answer came from ("↗ FARMAKOLOJİ · S. 13"), web pages it used, and what the assistant did.
    @ViewBuilder private func extras(_ m: ChatMessage) -> some View {
        let chips = m.outsidePdf ? [prefs.t("outsidePdf")] : m.sources.map { s in
            s.page.map { "↗ \(s.lesson) · \(prefs.t("pageLabel", ["n": Format.num($0, lang)]))" } ?? "↗ \(s.lesson)"
        }
        if !chips.isEmpty || !m.links.isEmpty || !m.acts.isEmpty {
            FlowLayout(spacing: 6, rowSpacing: 6) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                    Text(chip.uppercased(with: lang.locale)).font(KFont.mono(10, .regular)).foregroundStyle(KOnb.priText)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(KPhone.line, lineWidth: 1))
                }
                ForEach(Array(m.links.enumerated()), id: \.offset) { _, link in
                    if let url = URL(string: link.url) {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                KIcon(name: .globe, size: 11, width: 1.8)
                                Text(link.title).lineLimit(1)
                            }
                            .font(KFont.ui(11, lang: lang)).foregroundStyle(KPhone.text2)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(KPhone.sub, in: Capsule())
                        }
                    }
                }
                ForEach(Array(m.acts.enumerated()), id: \.offset) { _, act in
                    Text("\(prefs.t(act.kind == "weak" ? "actWeak" : "actCard")) \(act.title)")
                        .font(KFont.ui(11, .medium, lang: lang)).foregroundStyle(KPhone.good)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.pair(0xE3F1E7, 0x1F3328), in: Capsule())
                }
            }
            .frame(maxWidth: 340, alignment: .leading)
        }
    }

    private var offlineBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                KIcon(name: .wifiOff, size: 22, width: 1.7)
                Text(d("Bağlantı yok")).font(KFont.ui(15, .bold, lang: lang))
            }
            .foregroundStyle(KOnb.bad)
            Text(d("Asistan şu an cevap veremiyor. İndirilmiş hazır sorularla çalışmaya devam edebilirsin."))
                .font(KFont.ui(13, lang: lang)).kLineHeight(1.5, size: 13, lang: lang).foregroundStyle(KPhone.text)
            HStack(spacing: 8) {
                Button { app.back(fallback: .home) } label: {
                    Text(d("Hazır sorularla devam et")).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.ctaText)
                        .frame(maxWidth: .infinity, minHeight: 44).background(KOnb.pri, in: Capsule())
                }
                Button { toast.show(network.isOnline ? prefs.t("k165") : d("Bağlantı yok")) } label: {
                    Text(d("Tekrar dene")).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                        .padding(.horizontal, 16).frame(height: 44)
                        .background(KPhone.card, in: Capsule()).overlay(Capsule().stroke(KPhone.line, lineWidth: 1))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KOnb.badSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    // MARK: Composer

    private var composer: some View {
        VStack(spacing: 6) {
        HStack(spacing: 10) {
            Button { toast.show(prefs.t("k165")) } label: {
                KIcon(name: .sparkle, size: 20, width: 1.7).foregroundStyle(KPhone.text)
                    .frame(width: 48, height: 48).overlay(Circle().stroke(KPhone.line, lineWidth: 1))
            }
            .accessibilityLabel(prefs.t("quick"))
            TextField("", text: $draft, prompt: Text(d("Bu ders hakkında sor…")).foregroundStyle(KPhone.text3))
                .font(KFont.ui(15, lang: lang)).foregroundStyle(KPhone.text)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit(send)
                .padding(.horizontal, 18).frame(height: 48)
                .background(KPhone.sub, in: Capsule())
                .disabled(offline)
            let empty = draft.trimmingCharacters(in: .whitespaces).isEmpty
            Button { if empty { toast.show(prefs.t("k165")) } else { send() } } label: {
                KIcon(name: empty ? .mic : .paperPlane, size: 20, width: 1.8, flipsInRTL: !empty)
                    .foregroundStyle(KPhone.ctaText)
                    .frame(width: 48, height: 48)
                    .background(KOnb.pri.opacity(offline ? 0.4 : 1), in: Circle())
            }
            .disabled(offline)
            .accessibilityLabel(empty ? prefs.t("talk") : prefs.t("send"))
        }
        // Like every AI app: the assistant can be wrong.
        Text(prefs.t("aiNote")).font(KFont.ui(10.5, lang: lang)).foregroundStyle(KOnb.text3).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 8)
    }

    // MARK: Actions

    private func send() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !waiting, !offline else { return }
        trial.perform(.question) {
            draft = ""
            Task { await ask(question) }
        }
    }

    /// Adds the question and the answer while the server writes it; the server saves both and counts the question.
    private func ask(_ question: String) async {
        messages.append(ChatMessage(role: .user, text: question))
        waiting = true
        streaming = ""
        let result = await AssistantAPI.ask(question, courseId: isAll ? nil : target.topicId, threadId: threadId,
                                            mode: target.ai ? .ai : .pdf, lang: lang) { soFar in streaming = soFar }
        waiting = false
        streaming = nil
        switch result {
        case .success(let r):
            threadId = r.threadId
            messages.append(r.message)
        case .failure(let e):
            if e == .locked { trial.lockedKey = "trialQFull" } else {
                toast.show(prefs.t(e == .budget ? "askBudget" : e == .declined ? "askDeclined" : "askFailed"))
            }
        }
        await trial.refresh()
    }

    private func speak(_ text: String) {
        speaker.stop()
        speaker.speak(text, language: lang.rawValue, rate: Float(Self.speeds[speedIndex]), female: femaleVoice)
    }
}
