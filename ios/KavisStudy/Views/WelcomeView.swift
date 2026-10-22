import SwiftUI

/// Design: design/NewWelcome.dc.html. "Başlayalım" opens sign up, "Giriş yap" opens log in.
struct WelcomeView: View {
    @Environment(AppPrefs.self) private var prefs
    var onStart: () -> Void
    var onLogin: () -> Void

    var body: some View {
        let lang = prefs.lang
        VStack(spacing: 0) {
            Wordmark(size: 20)
                .padding(.top, KLayout.top(70))
            Image("BrandIcon")
                .resizable()
                .frame(width: 200, height: 200)
                .shadow(color: Color(hex: 0x7A5208, opacity: 0.35), radius: 20, y: 24)
                .padding(.top, 34)
                .accessibilityLabel(prefs.t("welcome.k1280"))
            VStack(spacing: 10) {
                Text("\(prefs.t("welcome.k2322"))\n\(prefs.t("welcome.k1486"))")
                    .foregroundStyle(KPhone.text)
                Text(prefs.t("welcome.k388"))
                    .foregroundStyle(KPhone.brand)
            }
            .font(KFont.ui(27, .medium, lang: lang))
            .kTracking(-0.02, size: 27, lang: lang)
            .lineSpacing(KFont.lineSpacing(1.2, size: 27, lang: lang))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22)
            .padding(.top, 30)
            Text(prefs.t("welcome.k1593"))
                .font(KFont.ui(15, lang: lang))
                .lineSpacing(KFont.lineSpacing(1.55, size: 15, lang: lang))
                .foregroundStyle(KPhone.text2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.top, 12)
            Spacer(minLength: 12)
            VStack(spacing: 12) {
                Button(action: onStart) {
                    Text(prefs.t("welcome.k482"))
                        .font(KFont.ui(17, .medium, lang: lang))
                        .foregroundStyle(KPhone.ctaText)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(KPhone.cta, in: Capsule())
                        .shadow(color: Color(hex: 0x9C2F3A, opacity: 0.28), radius: 15, y: 12)
                }
                Button(action: onLogin) {
                    (Text("\(prefs.t("welcome.k2326")) ").foregroundStyle(KPhone.text2)
                        + Text(prefs.t("welcome.k1061")).fontWeight(.semibold).foregroundStyle(KPhone.text))
                        .font(KFont.ui(13, lang: lang))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KPhone.welcomeBg.ignoresSafeArea())
    }
}
