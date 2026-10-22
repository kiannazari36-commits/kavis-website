import UIKit

/// Device limit (CLAUDE.md): max 2 devices per account, the web counts as one.
/// UI only for now: the list and the limit check are mock data until the server exists.
enum DeviceKind: String, Codable { case iphone, ipad, web }

struct Device: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let kind: DeviceKind
    let lastUsed: L10n?
    let current: Bool
}

enum DevicesAPI {
    static let maxDevices = 2
    private static let signedOutKey = "kavis.devices.signedOut"

    /// The other devices of the account (mock).
    private static let others: [Device] = [
        Device(id: "web", name: "Web · Safari · macOS", kind: .web, lastUsed: L10n(tr: "Bugün 09:12", en: "Today 09:12", fa: "امروز ۰۹:۱۲", ar: "اليوم 09:12"), current: false),
        Device(id: "ipad", name: "iPad Air", kind: .ipad, lastUsed: L10n(tr: "Dün 21:40", en: "Yesterday 21:40", fa: "دیروز ۲۱:۴۰", ar: "أمس 21:40"), current: false),
    ]

    private static func signedOut() -> [String] {
        UserDefaults.standard.stringArray(forKey: signedOutKey) ?? []
    }

    /// Name of this phone, e.g. "iPhone".
    static func thisDeviceName() -> String { UIDevice.current.model }

    /// Devices signed in to the account. Mock: this iPhone plus the web.
    static func listDevices() async -> [Device] {
        let web = others.filter { $0.id == "web" && !signedOut().contains($0.id) }
        let me = Device(id: "iphone", name: thisDeviceName(), kind: .iphone, lastUsed: nil, current: true)
        return await fakeRequest([me] + web, ms: 120)
    }

    /// Called after login. Returns the other devices when the account is already on 2 devices,
    /// so the student can choose one to sign out. Mock: full only with `-kavis.devices full`.
    static func checkDeviceLimit() async -> [Device]? {
        let remaining = others.filter { !signedOut().contains($0.id) }
        let full = MockFlag.value("devices") == "full"
        return await fakeRequest(full && remaining.count >= maxDevices ? remaining : nil, ms: 150)
    }

    static func signOutDevice(id: String) async -> Bool {
        UserDefaults.standard.set(signedOut() + [id], forKey: signedOutKey)
        return await fakeRequest(true)
    }
}
