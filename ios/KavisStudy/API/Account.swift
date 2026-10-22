import Foundation

struct Profile: Codable, Equatable {
    var name: String
    var email: String
    var school: String
}

enum AccountAPI {
    static func saveProfile(_ p: Profile) async -> Profile {
        await fakeRequest(p)
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
