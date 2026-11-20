import SwiftUI

/// Design: design/NewSupport.dc.html ("Yardım ve destek"): two tabs, the help chat and the frequently asked questions.
/// The chat is the web's help page (Edge Function `help-chat`, answers from a short public help text, nothing saved);
/// the e-mail button uses the same address, subject and text as the web. The design's ticket number, topic chips and
/// screenshot button belong to a ticket system we do not have, so they are not built.
struct SupportView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    @Environment(\.openURL) private var openURL

    private enum Tab { case chat, faq }
    private struct Msg: Identifiable {
        let id = UUID()
        let mine: Bool
        let text: String
        var error = false
    }

    @State private var tab: Tab = .chat
    @State private var msgs: [Msg] = []
    @State private var draft = ""
    @State private var busy = false
    @State private var escalate = false
    @State private var openFaq = -1

    private var lang: Lang { prefs.lang }
    private func t(_ key: String, _ vars: [String: String] = [:]) -> String { prefs.t(key, vars) }

    private enum C {
        static let card = Color.pair(0xFFFCF6, 0x211C18)
        static let seg = Color.pair(0xEAE1D2, 0x2B2520)
        static let pill = Color.pair(0xFFFCF6, 0x463C33)
        static let line = Color.pair(0xE6DDCF, 0x3A322B)
        static let text = Color.pair(0x2A2420, 0xEFE8DC)
        static let text2 = Color.pair(0x6E645A, 0xBDB2A4)
        static let bubble = Color.pair(0xFFFCF6, 0x2B2520)
        static let compBorder = Color.pair(0xF2D9A8, 0x4A3A1C)
        static let ambSoft = Color.pair(0xFBEBC8, 0x3A2E18)
        static let pri = Color(hex: 0x9C2F3A)
        static let onPri = Color(hex: 0xFFFCF6)
    }

    private var faq: [(q: String, a: String)] {
        [(prefs.d("PDF'im yüklenmiyor, ne yapmalıyım?"), prefs.d("Dosya taranmış sayfalardan oluşuyorsa \"Metin tanıma ile dene\" seçeneğini kullan. 100 MB üstü dosyaları bölerek yükle.")),
         (prefs.d("Asistan yanlış bir şey söyledi"), prefs.d("Cevabın altındaki kaynak sayfasını kontrol et ve buradan bize yaz; ilgili sayfayı inceleyip düzeltiriz.")),
         (prefs.d("Bildirimler gelmiyor"), t("hpFaqNotif")),
         (prefs.d("Aboneliğimi nasıl iptal ederim?"), prefs.d("App Store › Abonelikler bölümünden istediğin zaman iptal edebilirsin."))]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabs
            if tab == .chat { chat } else { faqList }
        }
        .padColumn()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KPhone.homeBg.ignoresSafeArea())
    }

    // MARK: Header and tabs

    private var header: some View {
        HStack(spacing: 12) {
            Button { app.back(fallback: .settings) } label: {
                KIcon(name: .back, size: 20, width: 1.8, flipsInRTL: true).foregroundStyle(C.text)
                    .frame(width: 46, height: 46).background(C.card, in: Circle()).overlay(Circle().stroke(C.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(prefs.d("Geri"))
            VStack(alignment: .leading, spacing: 1) {
                Text(prefs.d("Yardım ve destek")).font(KFont.ui(18, .semibold, lang: lang)).foregroundStyle(C.text)
                    .accessibilityAddTraits(.isHeader)
                Text(t("hpReply", ["h": String(HelpAPI.replyHours)])).font(KFont.ui(12, lang: lang)).foregroundStyle(C.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 10)
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            tabButton(.chat, prefs.d("Destekle konuş"))
            tabButton(.faq, prefs.d("Sık sorulanlar"))
        }
        .padding(4).background(C.seg, in: Capsule())
        .padding(.horizontal, 20).padding(.bottom, 10)
    }

    private func tabButton(_ id: Tab, _ title: String) -> some View {
        let on = tab == id
        return Button { tab = id } label: {
            Text(title).font(KFont.ui(13, on ? .semibold : .regular, lang: lang)).foregroundStyle(on ? C.text : C.text2)
                .frame(maxWidth: .infinity).frame(height: 38)
                .background(on ? C.pill : .clear, in: Capsule())
                .shadow(color: .black.opacity(on ? 0.12 : 0), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Chat

    private var chat: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        bubble(Msg(mine: false, text: t("hpHello")))
                        ForEach(msgs) { bubble($0) }
                        if busy {
                            Text(t("hpThinking")).font(KFont.ui(12, lang: lang)).foregroundStyle(C.text2)
                                .frame(maxWidth: .infinity, alignment: .leading).id("typing")
                        }
                        mailBox
                        Text(t("hpNote")).font(KFont.ui(11, lang: lang)).kLineHeight(1.5, size: 11, lang: lang).foregroundStyle(C.text2)
                            .multilineTextAlignment(.center).padding(.horizontal, 10).padding(.vertical, 4)
                        Color.clear.frame(height: 1).id("end")
                    }
                    .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: msgs.count) { _, _ in withAnimation { proxy.scrollTo("end", anchor: .bottom) } }
                .onChange(of: busy) { _, _ in withAnimation { proxy.scrollTo("end", anchor: .bottom) } }
            }
            if msgs.isEmpty { quick }
            composer
        }
    }

    private func bubble(_ m: Msg) -> some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: m.mine ? 18 : 6, bottomTrailingRadius: m.mine ? 6 : 18, topTrailingRadius: 18)
        return HStack(spacing: 0) {
            if m.mine { Spacer(minLength: 40) }
            Text(m.text).font(KFont.ui(14, lang: lang)).kLineHeight(1.5, size: 14, lang: lang)
                .foregroundStyle(m.mine ? C.onPri : C.text)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(m.mine ? C.pri : C.bubble, in: shape)
                .overlay(shape.stroke(C.line, lineWidth: m.mine ? 0 : 1))
                .textSelection(.enabled)
            if !m.mine { Spacer(minLength: 40) }
        }
    }

    /// The e-mail button is always there; after a failed or "ask a person" answer the question above it shows.
    private var mailBox: some View {
        VStack(spacing: 8) {
            if escalate { Text(t("hpEmailAsk")).font(KFont.ui(13, .semibold, lang: lang)).foregroundStyle(C.text).multilineTextAlignment(.center) }
            Button { openMail() } label: {
                HStack(spacing: 8) {
                    KIcon(name: .mail, size: 18, width: 1.7)
                    Text(t("hpEmailBtn")).font(KFont.ui(14, .medium, lang: lang))
                }
                .foregroundStyle(escalate ? C.onPri : C.text)
                .padding(.horizontal, 20).frame(height: 44)
                .background(escalate ? C.pri : C.card, in: Capsule())
                .overlay(Capsule().stroke(C.line, lineWidth: escalate ? 0 : 1))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity).padding(.top, 8)
    }

    private var quick: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(["hpQ1", "hpQ2", "hpQ3", "hpQ4"], id: \.self) { k in
                    Button { send(t(k)) } label: {
                        Text(t(k)).font(KFont.ui(12, lang: lang)).foregroundStyle(C.text).lineLimit(1)
                            .padding(.horizontal, 12).frame(height: 32)
                            .background(C.card, in: Capsule()).overlay(Capsule().stroke(C.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    private var composer: some View {
        HStack(spacing: 6) {
            TextField(t("hpPlaceholder"), text: $draft)
                .font(KFont.ui(15, lang: lang)).foregroundStyle(C.text)
                .submitLabel(.send).onSubmit { send(draft) }
                .padding(.horizontal, 14).frame(height: 42)
                .accessibilityLabel(t("hpPlaceholder"))
            Button { send(draft) } label: {
                KIcon(name: .plane, size: 17, width: 1.8, flipsInRTL: true).foregroundStyle(C.onPri)
                    .frame(width: 42, height: 42).background(C.pri, in: Circle())
                    .opacity(busy || draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .buttonStyle(.plain)
            .disabled(busy || draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel(t("hpSend"))
        }
        .padding(5)
        .background(C.card, in: Capsule()).overlay(Capsule().stroke(C.compBorder, lineWidth: 1.5))
        .padding(.horizontal, 12).padding(.bottom, 12)
    }

    // MARK: FAQ

    private var faqList: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    ForEach(Array(faq.enumerated()), id: \.offset) { i, f in
                        if i > 0 { Rectangle().fill(C.line).frame(height: 1) }
                        Button { withAnimation(.easeInOut(duration: 0.18)) { openFaq = openFaq == i ? -1 : i } } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(f.q).font(KFont.ui(14, .medium, lang: lang)).foregroundStyle(C.text).multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(openFaq == i ? "−" : "+").font(KFont.ui(14, lang: lang)).foregroundStyle(C.text2)
                                }
                                if openFaq == i {
                                    Text(f.a).font(KFont.ui(13, lang: lang)).kLineHeight(1.55, size: 13, lang: lang).foregroundStyle(C.text2)
                                        .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.vertical, 12).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(openFaq == i ? "expanded" : "collapsed")
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(C.card, in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(C.line, lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(prefs.d("Talebe otomatik eklenenler")).font(KFont.ui(13, .semibold, lang: lang))
                    Text(t("hpDevNote", ["v": appVersion, "dev": deviceName])).font(KFont.ui(12, lang: lang)).kLineHeight(1.5, size: 12, lang: lang)
                }
                .foregroundStyle(C.text)
                .padding(.horizontal, 16).padding(.vertical, 14).frame(maxWidth: .infinity, alignment: .leading)
                .background(C.ambSoft, in: RoundedRectangle(cornerRadius: 22))

                Button { tab = .chat } label: {
                    Text(t("hpFaqMore")).font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(C.onPri)
                        .frame(maxWidth: .infinity).frame(height: 50).background(C.pri, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 40)
        }
    }

    // MARK: Actions

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "1.0") (\(info?["CFBundleVersion"] as? String ?? "1"))"
    }
    private var deviceName: String { UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone" }

    private func openMail() {
        let last = msgs.last(where: { $0.mine })?.text ?? ""
        if let url = HelpAPI.mailURL(subject: t("hpMailSubject"), body: t("hpMailBody"), lastQuestion: last) { openURL(url) }
    }

    private func send(_ text: String) {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !busy else { return }
        msgs.append(Msg(mine: true, text: q))
        draft = ""
        busy = true
        let turns = msgs.filter { !$0.error }.map { HelpAPI.Turn(role: $0.mine ? "user" : "assistant", content: $0.text) }
        Task {
            let res = await HelpAPI.ask(turns, lang: lang.rawValue)
            busy = false
            switch res {
            case .answer(let a, let esc):
                msgs.append(Msg(mine: false, text: a.isEmpty ? t("hpError") : a))
                if esc { escalate = true }
            case .limit:
                msgs.append(Msg(mine: false, text: t("hpLimit"), error: true)); escalate = true
            case .failed:
                msgs.append(Msg(mine: false, text: t("hpError"), error: true)); escalate = true
            }
        }
    }
}
