import Foundation

/// Only what the app made can be shared — never the original PDF (CLAUDE.md, Premium only).
enum ShareItem { case summary, cards, quiz }

enum ShareAPI {
    /// Creates a share link. Mock: a random id; the link opens the web page /s/:id
    /// ("To open this, download the Kavis Study app", no preview).
    static func createLink(pdfId: String, items: [ShareItem]) async -> URL {
        let id = String(UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(8))
        return await fakeRequest(URL(string: "\(Config.webBaseURL)/s/\(id)")!, ms: 200)
    }
}
