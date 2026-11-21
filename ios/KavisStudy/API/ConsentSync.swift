import Foundation
import Supabase

/// Proof of consent on the server (KVKK): the terms version, "I am over 18" and the AI consent go to the SQL function
/// `record_consent(p_terms_version, p_adult, p_ai)`. A failed call never blocks the student: the answer stays on the
/// phone and is sent again at the next launch. (The local `AIConsent` flag stays as it is.)
enum ConsentSync {
    /// Version of the terms + privacy notice the student agreed to (change it when the texts change).
    static let termsVersion = "2026-11"

    private struct Record: Codable { var adult: Bool; var ai: Bool; var version: String; var at: Date }

    private static let stagedKey = "kavis.consent.staged"
    private static func pendingKey(_ uid: String) -> String { "kavis.consent.pending.\(uid)" }

    private static func load(_ key: String) -> Record? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(Record.self, from: $0) }
    }
    private static func save(_ r: Record, _ key: String) {
        if let data = try? JSONEncoder().encode(r) { UserDefaults.standard.set(data, forKey: key) }
    }

    /// Email sign-up: the boxes were ticked before the account exists; they are sent right after the first sign-in.
    static func stage(adult: Bool, ai: Bool) {
        save(Record(adult: adult, ai: ai, version: termsVersion, at: Date()), stagedKey)
    }

    static func clearStage() { UserDefaults.standard.removeObject(forKey: stagedKey) }

    /// After a sign-in: sends the staged sign-up answer (when it is fresh) and any answer that failed earlier.
    static func flush(userId: String) async {
        if let staged = load(stagedKey) {
            clearStage()
            if Date().timeIntervalSince(staged.at) < 24 * 3600 { save(staged, pendingKey(userId)) }
        }
        await retryPending(userId: userId)
    }

    /// The student answered the one-time sheet (Apple / Google sign-in).
    static func record(adult: Bool, ai: Bool, userId: String) async {
        save(Record(adult: adult, ai: ai, version: termsVersion, at: Date()), pendingKey(userId))
        await retryPending(userId: userId)
    }

    /// Tries again with an answer that is still waiting; the answer is kept when the server cannot be reached.
    static func retryPending(userId: String) async {
        guard let r = load(pendingKey(userId)), supabase.auth.currentUser != nil else { return }
        struct Params: Encodable { let p_terms_version: String; let p_adult: Bool; let p_ai: Bool }
        do {
            try await supabase.rpc("record_consent", params: Params(p_terms_version: r.version, p_adult: r.adult, p_ai: r.ai)).execute()
            UserDefaults.standard.removeObject(forKey: pendingKey(userId))
        } catch {
            // Stays saved; the next launch tries again.
        }
    }
}
