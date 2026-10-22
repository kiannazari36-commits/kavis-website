import SwiftUI

/// Temporary first screen: shows the brand, colors, fonts, language and light / dark switch
/// so the design tokens can be checked before the real screens are built. Replaced in step 3.
struct DesignCheckView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(\.colorScheme) private var scheme

    private let swatches: [(String, Color)] = [
        ("bg", KColor.bg), ("card", KColor.card), ("line", KColor.line), ("text", KColor.text),
        ("text2", KColor.text2), ("pri", KColor.pri), ("amb", KColor.amb), ("good", KColor.good),
        ("vio", KColor.vio), ("bad", KColor.bad), ("priSoft", KColor.priSoft), ("ambSoft", KColor.ambSoft),
    ]

    var body: some View {
        @Bindable var prefs = prefs
        let lang = prefs.lang

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(lang)

                card {
                    label("Language", lang)
                    Picker("Language", selection: $prefs.lang) {
                        ForEach(Lang.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    label("Theme", lang)
                    Picker("Theme", selection: $prefs.theme) {
                        Text("Auto").tag(ThemeChoice.system)
                        Text("Light").tag(ThemeChoice.light)
                        Text("Dark").tag(ThemeChoice.dark)
                    }
                    .pickerStyle(.segmented)
                }

                card {
                    label("Fonts", lang)
                    Text(lang.name).font(KFont.ui(22, .semibold, lang: lang)).foregroundStyle(KColor.text)
                    Text(lang.name).font(KFont.reading(20, lang: lang)).foregroundStyle(KColor.text)
                    Text(lang.name).font(KFont.reading(20, italic: true, lang: lang)).foregroundStyle(KColor.text2)
                    Text("62%  ·  160 min  ·  48/48").font(KFont.mono(16)).foregroundStyle(KColor.priText)
                }

                card {
                    label("Colors", lang)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        ForEach(swatches, id: \.0) { name, color in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(color)
                                    .frame(height: 44)
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(KColor.line, lineWidth: 1))
                                Text(name).font(KFont.mono(10)).foregroundStyle(KColor.text3)
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button("Primary") {}.buttonStyle(PillButtonStyle(kind: .primary, lang: lang))
                    Button("Secondary") {}.buttonStyle(PillButtonStyle(kind: .secondary, lang: lang))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(KGradient.landing.ignoresSafeArea())
    }

    private func header(_ lang: Lang) -> some View {
        HStack(spacing: 14) {
            Image(scheme == .dark ? "BrandIconDark" : "BrandIcon")
                .resizable()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Kavis Study").font(KFont.ui(26, .bold, lang: .en)).foregroundStyle(KColor.text)
                Text("Always Improve More").font(KFont.ui(14, lang: .en)).foregroundStyle(KColor.text2)
            }
        }
    }

    private func label(_ text: String, _ lang: Lang) -> some View {
        Text(text.uppercased()).font(KFont.ui(11, .semibold, lang: .en)).tracking(1).foregroundStyle(KColor.text3)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .kCard()
    }
}

#Preview {
    DesignCheckView().environment(AppPrefs())
}
