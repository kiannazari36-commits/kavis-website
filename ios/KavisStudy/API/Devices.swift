import UIKit
import Supabase

/// Device limit (CLAUDE.md): max 2 devices per account, the web counts as one. The server keeps the list
/// (table user_devices) and enforces the limit (RPC register_device), the same as for the web.
enum DeviceKind: String, Codable { case iphone, ipad, android, mac, web }

struct Device: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let kind: DeviceKind
    /// Last time it was used (ISO date), nil for this phone.
    let lastUsed: String?
    let current: Bool
}

enum DevicesAPI {
    static let maxDevices = 2
    private static let installKey = "kavis.installId"

    /// This install's id: made once and kept on the phone (a new install is a new device).
    static var installId: String {
        if let id = UserDefaults.standard.string(forKey: installKey) { return id }
        let id = UUID().uuidString.lowercased()
        UserDefaults.standard.set(id, forKey: installKey)
        return id
    }

    /// Readable name of this device, e.g. "iPhone 15 Pro · iOS 18" (the name the user gave it is not available
    /// without an entitlement, so the model name comes from the hardware identifier).
    static func thisDeviceName() -> String {
        let info = ProcessInfo.processInfo
        // In the simulator the real model is in this variable.
        let id = info.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? hardwareIdentifier()
        let fallback = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        return "\(modelName(for: id, fallback: fallback)) · iOS \(info.operatingSystemVersion.majorVersion)"
    }

    private static func hardwareIdentifier() -> String {
        var sys = utsname()
        uname(&sys)
        return withUnsafePointer(to: &sys.machine) { $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) } }
    }

    /// "iPhone16,1" → "iPhone 15 Pro". An unknown (newer) identifier gives the fallback, "iPhone" or "iPad".
    static func modelName(for identifier: String, fallback: String) -> String {
        let names: [String: String] = [
            "iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max", "iPhone12,8": "iPhone SE (2nd gen)",
            "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12", "iPhone13,3": "iPhone 12 Pro", "iPhone13,4": "iPhone 12 Pro Max",
            "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max", "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13",
            "iPhone14,6": "iPhone SE (3rd gen)", "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max", "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max", "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus", "iPhone17,5": "iPhone 16e",
            "iPhone18,1": "iPhone 17 Pro", "iPhone18,2": "iPhone 17 Pro Max", "iPhone18,3": "iPhone 17", "iPhone18,4": "iPhone Air",
            "iPad13,4": "iPad Pro 11", "iPad13,5": "iPad Pro 11", "iPad13,6": "iPad Pro 11", "iPad13,7": "iPad Pro 11",
            "iPad13,8": "iPad Pro 12.9", "iPad13,9": "iPad Pro 12.9", "iPad13,10": "iPad Pro 12.9", "iPad13,11": "iPad Pro 12.9",
            "iPad14,3": "iPad Pro 11", "iPad14,4": "iPad Pro 11", "iPad14,5": "iPad Pro 12.9", "iPad14,6": "iPad Pro 12.9",
            "iPad16,3": "iPad Pro 11", "iPad16,4": "iPad Pro 11", "iPad16,5": "iPad Pro 13", "iPad16,6": "iPad Pro 13",
            "iPad13,1": "iPad Air (4th gen)", "iPad13,2": "iPad Air (4th gen)", "iPad13,16": "iPad Air (5th gen)", "iPad13,17": "iPad Air (5th gen)",
            "iPad14,8": "iPad Air 11", "iPad14,9": "iPad Air 11", "iPad14,10": "iPad Air 13", "iPad14,11": "iPad Air 13",
            "iPad14,1": "iPad mini (6th gen)", "iPad14,2": "iPad mini (6th gen)", "iPad16,1": "iPad mini (A17 Pro)", "iPad16,2": "iPad mini (A17 Pro)",
            "iPad12,1": "iPad (9th gen)", "iPad12,2": "iPad (9th gen)", "iPad13,18": "iPad (10th gen)", "iPad13,19": "iPad (10th gen)",
        ]
        return names[identifier] ?? fallback
    }

    private static var kind: DeviceKind { UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone }

    private struct Row: Decodable {
        let id: String
        let install_id: String?
        let name: String
        let kind: DeviceKind
        let last_seen_at: String
    }

    /// Devices signed in to the account (this phone first).
    static func listDevices() async -> [Device] {
        let rows: [Row] = (try? await supabase.from("user_devices")
            .select("id, install_id, name, kind, last_seen_at")
            .is("signed_out_at", value: nil)
            .order("last_seen_at", ascending: false)
            .execute().value) ?? []
        return rows
            .map { Device(id: $0.id, name: $0.name, kind: $0.kind, lastUsed: $0.install_id == installId ? nil : $0.last_seen_at, current: $0.install_id == installId) }
            .sorted { $0.current && !$1.current }
    }

    /// Registers this phone after every login and at start. Returns the other devices when the account is already
    /// on 2 devices: then the student must sign one out first.
    static func checkDeviceLimit() async -> [Device]? {
        struct Params: Encodable { let p_install_id: String; let p_kind: String; let p_name: String; let p_app_version: String? }
        struct Result: Decodable { let ok: Bool; let devices: [Row]? }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard let r: Result = try? await supabase
            .rpc("register_device", params: Params(p_install_id: installId, p_kind: kind.rawValue, p_name: thisDeviceName(), p_app_version: version))
            .execute().value
        else { return nil }
        if r.ok { return nil }
        return (r.devices ?? []).map { Device(id: $0.id, name: $0.name, kind: $0.kind, lastUsed: $0.last_seen_at, current: false) }
    }

    /// Whether another device signed this phone out (then the app logs out here too).
    static func signedOutElsewhere() async -> Bool {
        struct Row: Decodable { let signed_out_at: String? }
        let rows: [Row] = (try? await supabase.from("user_devices").select("signed_out_at").eq("install_id", value: installId).limit(1).execute().value) ?? []
        return rows.first?.signed_out_at != nil
    }

    static func signOutDevice(id: String) async -> Bool {
        struct Params: Encodable { let p_device_id: String }
        let ok: Bool? = try? await supabase.rpc("sign_out_device", params: Params(p_device_id: id)).execute().value
        return ok == true
    }

    /// On "log out": frees this phone's device slot before the login ends.
    static func signOutThisDevice() async {
        if let me = await listDevices().first(where: \.current) { _ = await signOutDevice(id: me.id) }
    }
}
