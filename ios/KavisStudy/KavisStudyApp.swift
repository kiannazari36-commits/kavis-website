import SwiftUI

@main
struct KavisStudyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
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
                // Renewals and purchases approved later go to the server while the app runs (StoreKit 2).
                .task {
                    let model = trial
                    _ = StoreAPI.listen { await model.refresh() }
                }
        }
    }
}
