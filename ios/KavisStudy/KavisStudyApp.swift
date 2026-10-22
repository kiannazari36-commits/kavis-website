import SwiftUI

@main
struct KavisStudyApp: App {
    @State private var prefs = AppPrefs()
    @State private var app = AppModel()
    @State private var toast = ToastCenter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(prefs)
                .environment(app)
                .environment(toast)
                .environment(\.layoutDirection, prefs.lang.layoutDirection)
                .environment(\.locale, prefs.lang.locale)
                .preferredColorScheme(prefs.theme.colorScheme)
        }
    }
}
