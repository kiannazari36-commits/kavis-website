import Foundation
import Supabase

/// Invite codes: free Premium for the days the code grants (Edge Function `redeem-code`, same as the web).
enum PromoAPI {
    enum Result {
        case ok(endsAt: Date?)
        case error(String)   // unknown | expired | used_up | already_redeemed | promo_active | already_premium | rate_limited | failed
    }

    private static let known: Set<String> = ["unknown", "expired", "used_up", "already_redeemed", "promo_active", "already_premium", "rate_limited"]

    static func parseDate(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }

    static func redeem(_ code: String) async -> Result {
        struct Body: Encodable { let code: String }
        struct Answer: Decodable { let ok: Bool?; let error: String?; let ends_at: String? }
        do {
            let a: Answer = try await supabase.functions.invoke("redeem-code", options: FunctionInvokeOptions(body: Body(code: code)))
            if a.ok == true { return .ok(endsAt: a.ends_at.flatMap(parseDate)) }
            return .error(known.contains(a.error ?? "") ? a.error! : "failed")
        } catch FunctionsError.httpError(_, let data) {
            // 429 (too many wrong tries) still carries our JSON body.
            if let a = try? JSONDecoder().decode(Answer.self, from: data), let e = a.error, known.contains(e) { return .error(e) }
            return .error("failed")
        } catch {
            return .error("failed")
        }
    }
}
