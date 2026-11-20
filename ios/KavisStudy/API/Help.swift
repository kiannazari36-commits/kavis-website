import Foundation
import UIKit
import Supabase

/// The AI help chat (Edge Function `help-chat`, Claude Haiku), the same call as the web's `askHelp`. Nothing is saved:
/// the screen keeps the chat in memory and sends the last few turns each time.
enum HelpAPI {
    /// Same address and answer time as the web (web/src/config.ts).
    static let supportEmail = "kavisstudy@gmail.com"
    static let replyHours = 24

    struct Turn: Codable { let role: String; let content: String }
    enum Result {
        case answer(String, escalate: Bool)
        case limit
        case failed
    }

    static func ask(_ messages: [Turn], lang: String) async -> Result {
        struct Body: Encodable { let messages: [Turn]; let lang: String }
        struct Answer: Decodable { let answer: String?; let escalate: Bool? }
        do {
            let a: Answer = try await supabase.functions.invoke("help-chat", options: FunctionInvokeOptions(body: Body(messages: Array(messages.suffix(6)), lang: lang)))
            guard let text = a.answer else { return .failed }
            return .answer(text, escalate: a.escalate ?? false)
        } catch FunctionsError.httpError(let code, _) {
            return code == 429 ? .limit : .failed
        } catch {
            return .failed
        }
    }

    /// "Bize e-posta yaz": subject and body as on the web, plus the app version and device on the last line.
    static func mailURL(subject: String, body: String, lastQuestion: String) -> URL? {
        let info = Bundle.main.infoDictionary
        let version = "\(info?["CFBundleShortVersionString"] as? String ?? "1.0") (\(info?["CFBundleVersion"] as? String ?? "1"))"
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = supportEmail
        c.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body.replacingOccurrences(of: "{q}", with: lastQuestion) + "\n\nKavis Study \(version), \(device)"),
        ]
        return c.url
    }
}
