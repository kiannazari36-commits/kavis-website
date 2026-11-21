import Foundation
import Observation
import Supabase

/// The student's agreement that lesson content is sent to the AI provider (Anthropic) — Apple review 5.1.2(i).
/// Email sign-up asks for it with the consent tick box; Apple / Google sign-in and older accounts get a one-time
/// sheet. The answer is stored on the account in the sign-in user's metadata (`ai_consent`: "accepted" / "declined",
/// `ai_consent_at`), no new table or column; a copy on this phone makes it work offline.
@Observable
final class AIConsent {
    static let shared = AIConsent()

    enum State { case unknown, accepted, declined }

    private(set) var state: State = .unknown
    /// Sheet on screen. `locked` = opened by an AI button after "no" (the friendly lock message).
    var sheet: Sheet?
    enum Sheet { case first, locked }

    private func localKey(_ id: String) -> String { "kavis.aiConsent.\(id)" }

    /// Reads the answer for the signed-in account (call after login / app start).
    @MainActor func load(userId: String) {
        let meta = supabase.auth.currentUser?.userMetadata["ai_consent"]?.stringValue
        let local = UserDefaults.standard.string(forKey: localKey(userId))
        switch meta ?? local {
        case "accepted": state = .accepted
        case "declined": state = .declined
        default:
            // Accounts made with email + password ticked the consent box at sign-up (it was required).
            let provider = supabase.auth.currentUser?.appMetadata["provider"]?.stringValue ?? "email"
            state = provider == "email" ? .accepted : .unknown
        }
    }

    /// Shows the first-time sheet when this account never answered.
    @MainActor func askIfNeeded() {
        if state == .unknown, sheet == nil { sheet = .first }
    }

    /// An AI button was pressed: true when it may run, otherwise the right sheet opens.
    @MainActor func allowsAI() -> Bool {
        switch state {
        case .accepted: return true
        case .unknown: sheet = .first; return false
        case .declined: sheet = .locked; return false
        }
    }

    /// `adult` = the "I am over 18" box of the one-time sheet; nil when the answer comes from Settings (no age box).
    @MainActor func answer(_ accepted: Bool, userId: String, adult: Bool? = nil) {
        state = accepted ? .accepted : .declined
        sheet = nil
        UserDefaults.standard.set(accepted ? "accepted" : "declined", forKey: localKey(userId))
        if let adult {
            // Proof of consent for the server; a failed call is repeated at the next launch.
            Task { await ConsentSync.record(adult: adult, ai: accepted, userId: userId) }
        }
        Task {
            let stamp = ISO8601DateFormatter().string(from: Date())
            _ = try? await supabase.auth.update(user: UserAttributes(data: [
                "ai_consent": .string(accepted ? "accepted" : "declined"),
                "ai_consent_at": .string(stamp)
            ]))
        }
    }
}
