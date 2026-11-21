import SwiftUI

/// One-time "your content goes to the AI provider (Anthropic)" sheet (Apple review 5.1.2(i)), for accounts that did
/// not tick the sign-up box (Apple / Google sign-in). `.locked` is the friendly message when an AI button is pressed
/// after "no".
struct AIConsentSheet: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(AppModel.self) private var app
    let sheet: AIConsent.Sheet
    /// The "I am over 18" box (shown in the first-time sheet only); both answers wait for it.
    @State private var adult = false

    var body: some View {
        let lang = prefs.lang
        let locked = sheet == .locked
        ZStack {
            Color(hex: 0x2A2420, opacity: 0.4).ignoresSafeArea()
            VStack(spacing: 12) {
                KIcon(name: locked ? .lock : .shield, size: 24)
                    .foregroundStyle(KPhone.tile1Text)
                    .frame(width: 52, height: 52)
                    .background(KPhone.tile1, in: Circle())
                Text(prefs.t(locked ? "aiOffTitle" : "aiTitle")).font(KFont.ui(17, .semibold, lang: lang)).foregroundStyle(KPhone.text)
                    .multilineTextAlignment(.center)
                Text(prefs.t(locked ? "aiOffBody" : "aiBody"))
                    .font(KFont.ui(14, lang: lang)).kLineHeight(1.5, size: 14, lang: lang)
                    .foregroundStyle(KPhone.text2).multilineTextAlignment(.center)
                if !locked {
                    Button { adult.toggle() } label: {
                        HStack(alignment: .top, spacing: 10) {
                            ZStack {
                                Circle().fill(adult ? KPhone.cta : .clear)
                                Circle().stroke(adult ? .clear : KPhone.text3, lineWidth: 1.5)
                                if adult { KIcon(name: .check, size: 13, width: 3).foregroundStyle(KPhone.ctaText) }
                            }
                            .frame(width: 22, height: 22)
                            Text(prefs.t("consentAdult")).font(KFont.ui(13, lang: lang)).kLineHeight(1.45, size: 13, lang: lang)
                                .foregroundStyle(KPhone.text2).multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(adult ? [.isSelected] : [])
                    .padding(.top, 2)
                }
                Button { AIConsent.shared.answer(true, userId: app.user?.id ?? "", adult: adult) } label: {
                    Text(prefs.t("aiAccept")).font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(KPhone.ctaText)
                        .frame(maxWidth: .infinity, minHeight: 48).background(KPhone.navActive, in: Capsule())
                }
                .padding(.top, 6)
                .disabled(!locked && !adult).opacity(!locked && !adult ? 0.5 : 1)
                Button {
                    if locked { AIConsent.shared.sheet = nil } else { AIConsent.shared.answer(false, userId: app.user?.id ?? "", adult: adult) }
                } label: {
                    Text(prefs.t(locked ? "aiLater" : "aiDecline")).font(KFont.ui(15, .medium, lang: lang)).foregroundStyle(KPhone.text)
                        .frame(maxWidth: .infinity, minHeight: 48).overlay(Capsule().stroke(KPhone.line, lineWidth: 1))
                }
                .disabled(!locked && !adult).opacity(!locked && !adult ? 0.5 : 1)
                Button { open("privacy") } label: {
                    Text(prefs.t("legalPrivacy")).font(KFont.ui(12, lang: lang)).underline().foregroundStyle(KPhone.text2).frame(minHeight: 32)
                }
            }
            .padding(22)
            .frame(maxWidth: 340)
            .background(KPhone.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(KPhone.line, lineWidth: 1))
            .padding(.horizontal, 24)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .transition(.opacity)
    }

    @Environment(\.openURL) private var openURL
    private func open(_ page: String) {
        if let url = URL(string: "\(Config.webBaseURL)/\(page)?lang=\(prefs.lang.rawValue)") { openURL(url) }
    }
}
