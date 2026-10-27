import SwiftUI
import UIKit

/// Design: design/NewIPad.dc.html share sheet ("sh"), same as the web's `ShareDialog.tsx`. Premium only (the reader
/// opens the paywall otherwise) and only what the app made: summary, cards, quiz. The design's PDF option is left
/// out: the PDF belongs to the teacher (CLAUDE.md). The link opens a web page that only says "download the app".
struct ShareDialog: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(ToastCenter.self) private var toast

    let materialId: String
    let lessonTitle: String
    let onClose: () -> Void

    @State private var picked: Set<ShareAPI.Item> = [.summary]
    /// The link made for the current choice (a new choice makes a new link).
    @State private var made: (items: Set<ShareAPI.Item>, url: URL)?
    @State private var busy = false
    @State private var systemSheet: SharedLink?

    private var lang: Lang { prefs.lang }
    private func t(_ key: String) -> String { prefs.t(key) }

    private static let items: [(ShareAPI.Item, String, String)] = [
        (.summary, "shareSum", "shareSumS"),
        (.cards, "shareCards", "shareCardsS"),
        (.quiz, "shareQuiz", "shareQuizS"),
    ]

    var body: some View {
        ZStack {
            Color(hex: 0x2A2420, opacity: 0.35).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("share")).font(KFont.ui(20, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                        Text(lessonTitle).font(KFont.ui(12, .regular, lang: lang)).foregroundStyle(KPhone.text2).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: onClose) {
                        KIcon(name: .close, size: 14, width: 2).foregroundStyle(KPhone.text2)
                            .frame(width: 36, height: 36).overlay(Circle().stroke(KPhone.line, lineWidth: 1))
                    }
                    .accessibilityLabel(t("close"))
                }
                .padding(.bottom, 2)
                Text(t("shareWhat")).font(KFont.ui(14, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                ForEach(Self.items, id: \.0) { item, title, sub in itemRow(item, title: title, sub: sub) }
                HStack(spacing: 8) {
                    KIcon(name: .lock, size: 14, width: 1.8)
                    Text(t("shareNoPdf")).font(KFont.ui(12, .regular, lang: lang))
                }
                .foregroundStyle(KPhone.text2)
                HStack(spacing: 8) {
                    way("shareCopy", icon: .send) { url in
                        UIPasteboard.general.url = url
                        toast.show(t("shareCopied"))
                    }
                    way("shareMsg", icon: .mail) { url in
                        let body = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        if let sms = URL(string: "sms:&body=\(body)") { UIApplication.shared.open(sms) }
                    }
                    way("shareOther", icon: .share) { url in systemSheet = SharedLink(url: url) }
                }
                if let made {
                    Text(made.url.absoluteString.replacingOccurrences(of: "https://", with: ""))
                        .font(KFont.mono(13, .regular)).foregroundStyle(KPhone.text)
                        .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                        .environment(\.layoutDirection, .leftToRight)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(KPhone.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
            }
            .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 22)
            .frame(maxWidth: 560)
            .background(KPhone.card, in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(KPhone.line, lineWidth: 1))
            .shadow(color: Color(hex: 0x2A2420, opacity: 0.3), radius: 35, y: 30)
            .padding(.horizontal, 16)
            .accessibilityAddTraits(.isModal)
        }
        .sheet(item: $systemSheet) { link in ActivitySheet(items: [link.url]).presentationDetents([.medium, .large]) }
    }

    private func itemRow(_ item: ShareAPI.Item, title: String, sub: String) -> some View {
        let on = picked.contains(item)
        return Button {
            if on { picked.remove(item) } else { picked.insert(item) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7).fill(on ? KPhone.cta : .clear)
                    RoundedRectangle(cornerRadius: 7).stroke(on ? .clear : KPhone.line, lineWidth: 1.5)
                    if on { KIcon(name: .check, size: 14, width: 2.6).foregroundStyle(KPhone.ctaText) }
                }
                .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t(title)).font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(KPhone.text)
                    Text(t(sub)).font(KFont.ui(12, .regular, lang: lang)).foregroundStyle(KPhone.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(on ? KPhone.tile1 : .clear, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(on ? KPhone.cta : KPhone.line, lineWidth: on ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func way(_ key: String, icon: KIconName, run: @escaping (URL) -> Void) -> some View {
        Button {
            Task { if let url = await link() { run(url) } }
        } label: {
            VStack(spacing: 6) {
                KIcon(name: icon, size: 20, width: 1.7)
                Text(t(key)).font(KFont.ui(12, .regular, lang: lang)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(KPhone.text)
            .frame(maxWidth: .infinity).frame(height: 72)
            .background(KPhone.sub, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(KPhone.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    /// The link for the ticked items: made once by the server, again only when the choice changes.
    private func link() async -> URL? {
        guard !picked.isEmpty else { toast.show(t("sharePickFirst")); return nil }
        if let made, made.items == picked { return made.url }
        busy = true
        defer { busy = false }
        let order = ShareAPI.Item.allCases.filter(picked.contains)
        guard let url = await ShareAPI.create(materialId: materialId, items: order) else {
            toast.show(t("shareFailed"))
            return nil
        }
        made = (picked, url)
        return url
    }
}

private struct SharedLink: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// The system share menu (Messages, Mail, AirDrop, …) for the link.
private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
