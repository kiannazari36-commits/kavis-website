import Foundation

struct User: Codable, Equatable {
    let id: String
    let name: String
    let email: String
}

enum AuthProvider { case apple, google }

enum AuthError: Error { case badCode }

/// Accounts. Mock only: the session is kept on the phone until the server exists.
enum AuthAPI {
    private static let sessionKey = "kavis.session"

    private static func save(_ user: User) -> User {
        if let data = try? JSONEncoder().encode(user) { UserDefaults.standard.set(data, forKey: sessionKey) }
        return user
    }

    static func currentUser() -> User? {
        guard let data = UserDefaults.standard.data(forKey: sessionKey) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }

    /// Creates the account; the server then emails a 6-digit code.
    static func signUp(name: String, email: String, password: String) async -> (pendingEmail: String, name: String) {
        await fakeRequest((email.isEmpty ? "elif@ogrenci.edu.tr" : email, name.isEmpty ? "Elif Yıldız" : name))
    }

    static func verifyEmail(email: String, name: String, code: String) async throws -> User {
        guard code.count == 6 else { throw AuthError.badCode }
        return save(await fakeRequest(User(id: "u1", name: name, email: email)))
    }

    static func resendCode(email: String) async -> Bool {
        await fakeRequest(true)
    }

    static func logIn(email: String, password: String) async -> User {
        save(await fakeRequest(User(id: "u1", name: "Elif Yıldız", email: email.isEmpty ? "elif@ogrenci.edu.tr" : email)))
    }

    /// Sign in with Apple (real one comes with the server) or Google.
    static func socialLogIn(_ provider: AuthProvider) async -> User {
        let host = provider == .apple ? "apple" : "google"
        return save(await fakeRequest(User(id: "u1", name: "Elif Yıldız", email: "elif@\(host).example")))
    }

    static func logOut() async {
        UserDefaults.standard.removeObject(forKey: sessionKey)
        _ = await fakeRequest(true, ms: 0)
    }
}
