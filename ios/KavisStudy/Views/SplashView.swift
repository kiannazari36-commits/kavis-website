import SwiftUI

/// Design: design/NewSplash.dc.html. Shows for about two seconds, a tap continues.
struct SplashView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(\.colorScheme) private var scheme
    var onContinue: () -> Void

    @State private var progress: CGFloat = 0.08

    private var barTrack: Color { Color(light: Color(hex: 0x2A2420, opacity: 0.12), dark: Color(hex: 0xEFE8DC, opacity: 0.16)) }
    private var bar: Color { Color.pair(0x9C2F3A, 0xF2B33D) }

    var body: some View {
        let lang = prefs.lang
        Button(action: onContinue) {
            VStack(spacing: 22) {
                Image("BrandIcon")
                    .resizable()
                    .frame(width: 180, height: 180)
                    .shadow(color: Color(hex: 0x7A5208, opacity: 0.35), radius: 20, y: 24)
                HStack(spacing: 0) {
                    Text("Kavis ").font(KFont.ui(34, .bold, lang: .en))
                    Text("Study").font(KFont.ui(34, .regular, lang: .en)).opacity(0.75)
                }
                .kTracking(-0.01, size: 34, lang: .en)
                .foregroundStyle(KPhone.text)
                Text(prefs.t("splash.k388"))
                    .font(KFont.ui(14, lang: lang))
                    .foregroundStyle(KPhone.text2)
                Capsule().fill(barTrack)
                    .frame(width: 120, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule().fill(bar).frame(width: 120 * progress, height: 4)
                    }
                    .padding(.top, 38)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KPhone.splashBg.ignoresSafeArea())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(prefs.t("splash.k804"))
        .task {
            withAnimation(.easeOut(duration: 2)) { progress = 1 }
            try? await Task.sleep(for: .milliseconds(2300))
            if !Task.isCancelled { onContinue() }
        }
    }
}
