import SwiftUI
import Observation

/// Short message for buttons that have no real action yet (CLAUDE.md: every button does something).
@Observable
final class ToastCenter {
    private(set) var message: String?
    private var task: Task<Void, Never>?

    func show(_ text: String) {
        message = text
        task?.cancel()
        task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(2200))
            if !Task.isCancelled { self?.message = nil }
        }
    }
}

extension View {
    /// Shows the current toast above everything, near the bottom.
    func toastOverlay(_ center: ToastCenter, bottom: CGFloat = 120, lang: Lang) -> some View {
        overlay(alignment: .bottom) {
            if let text = center.message {
                Text(text)
                    .font(KFont.ui(14, lang: lang))
                    .foregroundStyle(KPhone.toastText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(KPhone.toast, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color(hex: 0x2A2420, opacity: 0.28), radius: 15, y: 12)
                    .frame(maxWidth: 340)
                    .padding(.bottom, bottom)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .allowsHitTesting(false)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.easeOut(duration: 0.2), value: center.message)
    }
}
