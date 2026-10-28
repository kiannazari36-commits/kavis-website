import SwiftUI

/// "Davet kodum var": an invite code gives free Premium for a few weeks. No price, no buy button.
struct RedeemCodeView: View {
    @Environment(AppPrefs.self) private var prefs
    @Environment(TrialModel.self) private var trial

    @State private var open = false
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?

    private var lang: Lang { prefs.lang }
    private func t(_ key: String, _ vars: [String: String] = [:]) -> String { prefs.t(key, vars) }
    private let pri = Color.pair(0x9C2F3A, 0xF09AA3)

    static func dateText(_ d: Date, lang: Lang) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: lang.rawValue)
        f.dateStyle = .long
        return f.string(from: d)
    }

    var body: some View {
        VStack(spacing: 8) {
            if trial.status.premium, trial.status.premiumSource == "promo", let until = trial.status.premiumUntil {
                Text(t("codeActive", ["date": Self.dateText(until, lang: lang)]))
                    .font(KFont.ui(13, .semibold, lang: lang)).multilineTextAlignment(.center)
            } else if !open {
                Button { open = true } label: {
                    Text(t("codeHave")).font(KFont.ui(13, .semibold, lang: lang)).underline().foregroundStyle(pri).frame(minHeight: 36)
                }
            } else {
                Text(t("codeHint")).font(KFont.ui(12, lang: lang)).foregroundStyle(Color.pair(0x6E645A, 0xBDB2A4))
                HStack(spacing: 8) {
                    TextField("KAVIS-XXXXX", text: $code)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .font(.system(size: 14, design: .monospaced))
                        .padding(.horizontal, 16).frame(height: 44)
                        .background(Color.pair(0xFFFCF6, 0x211C18), in: Capsule())
                        .overlay(Capsule().stroke(Color.pair(0xE6DDCF, 0x3A322B)))
                        .environment(\.layoutDirection, .leftToRight)
                        .onSubmit { Task { await submit() } }
                    Button { Task { await submit() } } label: {
                        Text(t("codeApply")).font(KFont.ui(13, .semibold, lang: lang)).foregroundStyle(Color(hex: 0xFFFCF6))
                            .padding(.horizontal, 18).frame(height: 44)
                            .background(Color.pair(0x9C2F3A, 0xB23A47), in: Capsule())
                            .opacity(busy || code.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    }
                    .disabled(busy || code.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let error { Text(t("codeErr_\(error)")).font(KFont.ui(12, lang: lang)).foregroundStyle(pri).multilineTextAlignment(.center) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func submit() async {
        busy = true
        error = nil
        defer { busy = false }
        switch await PromoAPI.redeem(code) {
        case .ok:
            code = ""
            await trial.refresh()
        case .error(let e): error = e
        }
    }
}
