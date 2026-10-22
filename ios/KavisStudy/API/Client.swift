import Foundation

// Fake network layer. Replace these helpers with real URLSession calls when the server exists.
// Every function in this folder is `async`, so a real server can be plugged in without changing the screens.
let apiDelayMs = 450

func fakeRequest<T>(_ result: T, ms: Int = apiDelayMs) async -> T {
    if ms > 0 { try? await Task.sleep(for: .milliseconds(ms)) }
    return result
}

/// Web-like test switches for mock states, e.g. launch argument `-kavis.trial ended` or `-kavis.devices full`.
/// To be removed before the public launch (see TODO.md).
enum MockFlag {
    static func value(_ name: String) -> String? { UserDefaults.standard.string(forKey: "kavis.\(name)") }
}

/// Reads a bundled mock JSON file (copied from the web by `ios/scripts/sync-from-web.mjs`).
enum MockData {
    private final class BundleToken {}

    static func load<T: Decodable>(_ name: String, as type: T.Type = T.self) -> T {
        guard let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(T.self, from: data)
        else { fatalError("Mock data \(name).json is missing or has the wrong shape — run `node ios/scripts/sync-from-web.mjs`") }
        return value
    }
}
