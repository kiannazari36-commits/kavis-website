import SwiftUI

@main
struct KavisStudyApp: App {
    @State private var prefs = AppPrefs()

    var body: some Scene {
        WindowGroup {
            DesignCheckView()
                .environment(prefs)
                .environment(\.layoutDirection, prefs.lang.layoutDirection)
                .environment(\.locale, prefs.lang.locale)
                .preferredColorScheme(prefs.theme.colorScheme)
        }
    }
}
