import SwiftUI

/// Pill button (CLAUDE.md: pill buttons). Primary = bordo (amber in dark mode), secondary = outlined.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }

    var kind: Kind = .primary
    var lang: Lang

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KFont.ui(15, .semibold, lang: lang))
            .foregroundStyle(kind == .primary ? KColor.pf : KColor.text)
            .padding(.horizontal, 22)
            .frame(minHeight: 48)
            .background(kind == .primary ? KColor.pb : KColor.card, in: Capsule())
            .overlay(Capsule().stroke(kind == .primary ? Color.clear : KColor.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension View {
    /// Card surface: card color, 1 px line, radius 24.
    func kCard(radius: CGFloat = KRadius.card) -> some View {
        background(KColor.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(KColor.line, lineWidth: 1))
    }
}
