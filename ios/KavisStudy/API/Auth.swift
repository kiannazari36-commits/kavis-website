import Foundation
import Supabase

struct User: Codable, Equatable {
    let id: String
    let name: String
    let email: String
}

enum AuthProvider { case apple, google }

/// Why an auth call failed; each one is a text key `err<Reason>` (web/src/i18n/auth.json, copied to the app).
enum AuthFailure: String, Error {
    case code = "Code", login = "Login", unconfirmed = "Unconfirmed", rate = "Rate", weakPw = "WeakPw"
    case taken = "Taken", email = "Email", network = "Network", soon = "Soon", other = "Other"

    var textKey: String { "err\(rawValue)" }
}

/// Accounts (Supabase Auth, the same accounts as the web): email + password; the sign-up email confirms the
/// address with a link, or a 6-digit code when the email template has `{{ .Token }}`.
enum AuthAPI {
    private static func toUser(_ u: Auth.User?) -> User? {
        guard let u else { return nil }
        let meta = u.userMetadata
        let name = meta["full_name"]?.stringValue ?? meta["name"]?.stringValue ?? ""
        return User(id: u.id.uuidString.lowercased(), name: name, email: u.email ?? "")
    }

    /// The signed-in student from the saved session (Keychain), or nil.
    static func currentUser() -> User? { toUser(supabase.auth.currentUser) }

    private static func fail(_ error: Error) -> AuthFailure {
        if error is URLError { return .network }
        guard let e = error as? AuthError else { return .other }
        switch e.errorCode.rawValue {
        case "otp_expired": return .code
        case "invalid_credentials": return .login
        case "email_not_confirmed": return .unconfirmed
        case "over_email_send_rate_limit", "over_request_rate_limit": return .rate
        case "weak_password": return .weakPw
        case "user_already_exists", "email_exists": return .taken
        case "email_address_invalid", "validation_failed": return .email
        default: return .other
        }
    }

    /// Creates the account. Returns the student when the server signs in at once (no email confirmation),
    /// otherwise nil: a confirmation email (link or code) was sent.
    static func signUp(name: String, email: String, password: String, lang: Lang) async throws -> User? {
        do {
            let r = try await supabase.auth.signUp(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                data: ["full_name": .string(name.trimmingCharacters(in: .whitespaces)), "app_lang": .string(lang.rawValue)],
                redirectTo: URL(string: "\(Config.webBaseURL)/home")
            )
            // An email that already has a confirmed account comes back without identities, and no email is sent.
            if r.user.identities?.isEmpty == true { throw AuthFailure.taken }
            return r.session == nil ? nil : toUser(r.user)
        } catch let f as AuthFailure {
            throw f
        } catch {
            throw fail(error)
        }
    }

    /// The 6-digit code from the sign-up email.
    static func verifyEmail(email: String, code: String) async throws -> User {
        guard code.count == 6 else { throw AuthFailure.code }
        do {
            let r = try await supabase.auth.verifyOTP(email: email, token: code, type: .signup)
            guard let user = toUser(r.user) else { throw AuthFailure.other }
            return user
        } catch let f as AuthFailure {
            throw f
        } catch {
            throw fail(error)
        }
    }

    static func resendCode(email: String) async -> Bool {
        (try? await supabase.auth.resend(email: email, type: .signup)) != nil
    }

    static func logIn(email: String, password: String) async throws -> User {
        do {
            let s = try await supabase.auth.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
            guard let user = toUser(s.user) else { throw AuthFailure.other }
            return user
        } catch let f as AuthFailure {
            throw f
        } catch {
            throw fail(error)
        }
    }

    /// "Şifremi unuttum": emails a link to the web page where the new password is set.
    static func sendPasswordReset(email: String) async -> Bool {
        (try? await supabase.auth.resetPasswordForEmail(email, redirectTo: URL(string: "\(Config.webBaseURL)/login?mode=reset"))) != nil
    }

    /// Sign in with Apple / Google: needs the Apple developer account and the Google client (TODO.md).
    static func socialLogIn(_ provider: AuthProvider) async throws -> User {
        throw AuthFailure.soon
    }

    /// Whether the account still has to answer the first steps (profiles.onboarding_done).
    static func needsOnboarding() async -> Bool {
        guard let id = supabase.auth.currentUser?.id else { return false }
        struct Row: Decodable { let onboarding_done: Bool }
        let rows: [Row] = (try? await supabase.from("profiles").select("onboarding_done").eq("id", value: id).limit(1).execute().value) ?? []
        return rows.first.map { !$0.onboarding_done } ?? false
    }

    static func logOut() async {
        try? await supabase.auth.signOut()
    }
}
