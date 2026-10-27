import UIKit
import Supabase

/// Push notifications (APNs): this phone's notification code (device token) is saved on the server in
/// `push_tokens`, so `send-notifications` can push to it. Real pushes need the Apple key (TODO.md); until then
/// the simulator gives no token and nothing is sent.
enum PushService {
    private static let tokenKey = "kavis.apnsToken"

    /// The code this phone got from Apple last time (empty until Apple has given one).
    static var savedToken: String? { UserDefaults.standard.string(forKey: tokenKey) }

    /// Asks Apple for the code (when signed in). Apple answers in `AppDelegate`.
    @MainActor static func start() {
        UIApplication.shared.registerForRemoteNotifications()
        if let token = savedToken { Task { await register(token) } }
    }

    static func didGet(_ data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenKey)
        Task { await register(token) }
    }

    /// Saves the code for the signed-in account (the same code is only kept once, the newest owner wins).
    static func register(_ token: String) async {
        guard let uid = supabase.auth.currentUser?.id else { return }
        struct Row: Encodable { let user_id: String; let device_id: String?; let platform = "apns"; let token: String }
        let device = await DevicesAPI.listDevices().first(where: \.current)?.id
        _ = try? await supabase.from("push_tokens")
            .upsert(Row(user_id: uid.uuidString.lowercased(), device_id: device, token: token), onConflict: "token")
            .execute()
    }

    /// On "log out": this phone gets no pushes for the account any more.
    static func unregister() async {
        guard let token = savedToken else { return }
        _ = try? await supabase.from("push_tokens").delete().eq("token", value: token).execute()
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushService.didGet(deviceToken)
    }
}
