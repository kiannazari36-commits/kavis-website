import Foundation

enum Config {
    /// Test deploy of the web app (no custom domain yet). Share links open `<webBaseURL>/s/<id>`.
    static let webBaseURL = "https://kavis-website.vercel.app"

    /// The local Supabase copy on the Mac (`supabase start`) instead of the live project: launch argument
    /// `-kavis.server local` (simulator tests with fake accounts; removed before launch with the other switches).
    static var useLocalServer: Bool {
        #if DEBUG
        MockFlag.value("server") == "local"
        #else
        false
        #endif
    }

    /// Supabase address and publishable key, from Info.plist (filled from ios/Config/Secrets.xcconfig, not in git).
    /// Both are public by design; Row Level Security protects the data.
    static var supabaseURL: URL {
        let raw = info(useLocalServer ? "SupabaseLocalURL" : "SupabaseURL")
        guard let url = URL(string: raw), url.scheme != nil else { fatalError("Supabase URL missing — see ios/Config/Secrets.example.xcconfig") }
        return url
    }

    static var supabaseKey: String { info(useLocalServer ? "SupabaseLocalKey" : "SupabaseKey") }

    private static func info(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
    }
}
