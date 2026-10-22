import Foundation

struct Profile: Codable, Equatable {
    var name: String
    var email: String
    var school: String
    /// Department as the design writes it in Turkish ("Eczacılık"); shown through `prefs.d(...)`.
    var department: String = "Eczacılık"
    var year: Int = 3
}

enum AccountAPI {
    private static let profileKey = "kavis.profile"

    /// Profile of the signed-in student. Mock: kept on the phone; the first time it is made from the account.
    static func loadProfile(for user: User?) -> Profile {
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let saved = try? JSONDecoder().decode(Profile.self, from: data) { return saved }
        return Profile(name: user?.name ?? "Elif Yıldız", email: user?.email ?? "elif@ogrenci.edu.tr", school: "Ankara Üniversitesi")
    }

    static func saveProfile(_ p: Profile) async -> Profile {
        if let data = try? JSONEncoder().encode(p) { UserDefaults.standard.set(data, forKey: profileKey) }
        return await fakeRequest(p)
    }

    /// Emails the student a copy of their data.
    static func requestMyData() async -> Bool {
        await fakeRequest(true)
    }

    /// Starts account deletion: the server emails a confirmation link (30 days to change your mind).
    /// Deleting the account does not cancel an Apple subscription; the student cancels it in the App Store.
    static func deleteAccount() async -> Bool {
        await fakeRequest(true)
    }
}
