import SwiftUI

/// Design: design/ScrAssistant.dc.html (chat). The assistant answers only from the student's material; what it does
/// not find in the lesson it says so. Answers are a mock until the server exists. Voice, teach-back and
/// "easy explanation" modes of the design come later.
struct AssistantChatView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(ToastCenter.self) private var toast
    @Environment(TrialModel.self) private var trial
    @Environment(NetworkMonitor.self) private var network

    let target: AssistantChatTarget

    private struct Message: Identifiable {
        enum Role { case assistant, user }
        let id = UUID().uuidString
        let role: Role
        var text: String
        var source: String?
    }

    @State private var messages: [Message] = []
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
    private var topic: AssistantTopic? { AssistantAPI.topics.first { $0.id == target.topicId } }
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
            messages = [Message(role: .assistant, text: welcome)]
            if !target.question.isEmpty { await ask(target.question, alreadyShown: false) }
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
        let name = topic?.isAll == true ? d("Tüm derslerim") : "\(topic?.name[lang] ?? "").pdf"
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

    private var welcome: String {
        if topic?.isAll == true {
            return d("Merhaba! Tüm derslerindeki PDF, ses kaydı ve sınav sonuçlarına bakarak cevap veriyorum.")
        }
        var text = d("Merhaba! Yalnızca “Hipertansiyon” PDF'ine dayanarak cevap veriyorum. Şu an sayfa 12'desin.")
        guard target.topicId != "hypertension", let me = topic?.name[lang],
              let hyper = AssistantAPI.topics.first(where: { $0.id == "hypertension" })?.name[lang] else { return text }
        text = text.replacingOccurrences(of: hyper, with: me)
        // The page remark only fits the lesson the student is reading.
        if let end = text.firstIndex(of: "."), let next = text[end...].firstIndex(of: "."), next != end {
            text = String(text[...text.index(after: end)])
            if let cut = text.range(of: ". ") { text = String(text[..<cut.upperBound]).trimmingCharacters(in: .whitespaces) }
        }
        return text
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    if offline { offlineBanner }
                    ForEach(messages) { message in bubble(message).id(message.id) }
                    if waiting {
                        Text(d("Asistan cevap yazıyor…")).font(KFont.ui(12, lang: lang)).foregroundStyle(KOnb.text3)
                            .frame(maxWidth: .infinity, alignment: .leading).id("typing")
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
        }
    }

    private func bubble(_ message: Message) -> some View {
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
            if let source = message.source {
                Text(source.uppercased()).font(KFont.mono(10, .regular)).foregroundStyle(KOnb.priText)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(KPhone.line, lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
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
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 10)
    }

    // MARK: Actions

    private func send() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !waiting, !offline else { return }
        trial.perform(.question) {
            draft = ""
            Task { await ask(question, alreadyShown: false) }
        }
    }

    /// Adds the question, waits for the (mock) server and adds the answer. Every question counts for the trial.
    private func ask(_ question: String, alreadyShown: Bool) async {
        messages.append(Message(role: .user, text: question))
        waiting = true
        if !trial.status.premium { trial.status.questionsUsed += 1 }
        let reply = await AssistantAPI.ask(topicId: target.topicId, question: question, ai: target.ai, lang: lang)
        waiting = false
        messages.append(Message(role: .assistant, text: reply.text, source: reply.source))
    }

    private func speak(_ text: String) {
        speaker.stop()
        speaker.speak(text, language: lang.rawValue, rate: Float(Self.speeds[speedIndex]), female: femaleVoice)
    }
}
