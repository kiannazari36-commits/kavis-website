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

    /// Name of this phone, e.g. "iPhone" or "iPad".
    static func thisDeviceName() -> String { UIDevice.current.model }

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
