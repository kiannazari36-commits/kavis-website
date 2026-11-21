import SwiftUI
import UIKit

/// "Reduce Motion" (Settings > Accessibility): the app's own animations are switched off when the student asks for it.
/// Use `kAnimate { … }` instead of `withAnimation { … }` and `.kAnimation(_, value:)` instead of `.animation(_, value:)`.
/// (A loading spinner that has to turn is the one exception and keeps `withAnimation`.)
func kAnimate<R>(_ animation: Animation? = .default, _ body: () throws -> R) rethrows -> R {
    try withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : animation, body)
}

extension View {
    func kAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        self.animation(UIAccessibility.isReduceMotionEnabled ? nil : animation, value: value)
    }
}

/// Hardware keyboard shortcuts (iPad with a keyboard). Each one is an invisible button that only exists on screen
/// while its view is there: `.background(KeyShortcut(.escape) { close() })`.
struct KeyShortcut: View {
    let key: KeyEquivalent
    var modifiers: EventModifiers = []
    let action: () -> Void

    init(_ key: KeyEquivalent, modifiers: EventModifiers = [], action: @escaping () -> Void) {
        self.key = key; self.modifiers = modifiers; self.action = action
    }

    var body: some View {
        Button(action: action) { Color.clear }
            .keyboardShortcut(key, modifiers: modifiers)
            .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)
    }
}
