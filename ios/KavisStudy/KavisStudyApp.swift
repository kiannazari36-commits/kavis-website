import SwiftUI

@main
struct KavisStudyApp: App {
    @State private var prefs = AppPrefs()
    @State private var app = AppModel()
    @State private var toast = ToastCenter()
    @State private var trial = TrialModel()
    @State private var network = NetworkMonitor()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(prefs)
                .environment(app)
                .environment(toast)
                .environment(trial)
                .environment(network)
                .environment(\.layoutDirection, prefs.lang.layoutDirection)
                .environment(\.locale, prefs.lang.locale)
                .preferredColorScheme(prefs.theme.colorScheme)
        }
    }
}
