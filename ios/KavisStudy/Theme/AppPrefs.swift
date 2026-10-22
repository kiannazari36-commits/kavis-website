import SwiftUI
import Observation

enum ThemeChoice: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    /// nil = follow the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Interface language and appearance, remembered between launches.
/// Like the web (`?lang=fa`), a launch argument can set them for testing: `-kavis.lang fa -kavis.theme dark`.
@Observable
final class AppPrefs {
    private static let langKey = "kavis.lang"
    private static let themeKey = "kavis.theme"

    var lang: Lang {
        didSet { UserDefaults.standard.set(lang.rawValue, forKey: Self.langKey) }
    }

    var theme: ThemeChoice {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.themeKey) }
    }

    init() {
        let d = UserDefaults.standard
        lang = d.string(forKey: Self.langKey).flatMap(Lang.init(rawValue:)) ?? .tr
        theme = d.string(forKey: Self.themeKey).flatMap(ThemeChoice.init(rawValue:)) ?? .system
    }
}
