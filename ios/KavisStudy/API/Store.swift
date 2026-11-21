import StoreKit
import Supabase

/// Premium with Apple in-app purchase (StoreKit 2), the only way to buy it (CLAUDE.md). Prices come from the App
/// Store (Apple sets them per country), never from the code. Every transaction goes to the server (Edge Function
/// apple-purchase), which checks Apple's signature and keeps Premium in the account, so the web opens too.
/// Local testing: the scheme's StoreKit configuration `KavisStudy.storekit` (Xcode) simulates the App Store.
enum StoreAPI {
    static let productIds = ["study.kavis.premium.year", "study.kavis.premium.term", "study.kavis.premium.month"]

    /// The plans in the paywall's order (yearly, term, monthly); empty when the App Store cannot be reached.
    static func products() async -> [Product] {
        let list = (try? await Product.products(for: productIds)) ?? []
        return productIds.compactMap { id in list.first { $0.id == id } }
    }

    enum BuyResult: Equatable { case premium, pending, cancelled, failed, refused(Refusal) }

    /// Why the server will not give Premium for a transaction (HTTP 403 of `apple-purchase`), shown as a plain message.
    enum Refusal: Equatable {
        /// The purchase belongs to another Kavis account (403 `account`).
        case account
        /// Test (sandbox) purchases are not allowed for this account (403 `sandbox`).
        case sandbox
        /// The account has no active subscription (`no_subscription`).
        case noSubscription

        /// Text key of the message (i18n-ios.json).
        var messageKey: String {
            switch self {
            case .account: "pwRefusedAccount"
            case .sandbox: "pwRefusedSandbox"
            case .noSubscription: "pwNoSubscription"
            }
        }
    }

    /// What the server said about one transaction.
    enum Sent: Equatable {
        /// Accepted; `premium` tells whether the account is Premium now (false after a refund or an expiry).
        case accepted(premium: Bool)
        /// Refused for good (retrying will never help).
        case refused(Refusal)
        /// Rejected for good with a code we do not know (bad signature …): not retried either.
        case rejected
        /// Offline or a server error: try again later.
        case retryLater

        var isFinal: Bool { self != .retryLater }
        var premium: Bool { if case .accepted(true) = self { true } else { false } }
    }

    /// Buys a plan. The purchase carries the student's account id (appAccountToken), so the server can only give it
    /// to this account. The transaction is finished only after the server has answered for good.
    static func buy(_ product: Product) async -> BuyResult {
        guard let uid = supabase.auth.currentUser?.id else { return .failed }
        do {
            switch try await product.purchase(options: [.appAccountToken(uid)]) {
            case .success(let result):
                guard case .verified(let t) = result else { return .failed }
                let sent = await send(result.jwsRepresentation)
                // A failed send keeps the transaction open: the next launch (or `listen`) sends it again.
                if sent.isFinal { await t.finish() }
                switch sent {
                case .accepted(let premium): return premium ? .premium : .failed
                case .refused(let r): return .refused(r)
                case .rejected, .retryLater: return .failed
                }
            case .pending: return .pending
            case .userCancelled: return .cancelled
            @unknown default: return .failed
            }
        } catch {
            return .failed
        }
    }

    /// Sends a signed transaction to the server and maps the answer.
    static func send(_ signedTransaction: String) async -> Sent {
        struct Body: Encodable { let action = "purchase"; let signed_transaction: String }
        struct Res: Decodable { let premium: Bool?; let error: String? }
        do {
            let r: Res = try await supabase.functions.invoke("apple-purchase", options: FunctionInvokeOptions(body: Body(signed_transaction: signedTransaction)))
            if let refusal = refusal(code: r.error) { return .refused(refusal) }
            return .accepted(premium: r.premium == true)
        } catch FunctionsError.httpError(let status, let data) {
            struct Err: Decodable { let error: String? }
            let code = (try? JSONDecoder().decode(Err.self, from: data))?.error
            if let refusal = refusal(code: code) { return .refused(refusal) }
            // 4xx = the server looked at it and said no; 5xx = try again later.
            return status >= 400 && status < 500 && status != 401 && status != 429 ? .rejected : .retryLater
        } catch {
            return .retryLater
        }
    }

    /// Known refusal codes; unknown codes are handled as a general failure.
    static func refusal(code: String?) -> Refusal? {
        switch code {
        case "account": .account
        case "sandbox": .sandbox
        case "no_subscription": .noSubscription
        default: nil
        }
    }

    enum RestoreResult: Equatable { case premium, none, refused(Refusal), noStore, failed }

    /// "Satın alımları geri yükle": asks the App Store for this Apple Account's purchases and sends them to the server.
    static func restore() async -> RestoreResult {
        guard (try? await AppStore.sync()) != nil else { return .noStore }
        var signed: [String] = []
        for await result in Transaction.currentEntitlements {
            if case .verified = result { signed.append(result.jwsRepresentation) }
        }
        // The server's `restore` action decides (also when the phone found nothing).
        struct Body: Encodable { let action = "restore"; let signed_transactions: [String] }
        struct Res: Decodable { let premium: Bool? }
        do {
            let r: Res = try await supabase.functions.invoke("apple-purchase", options: FunctionInvokeOptions(body: Body(signed_transactions: signed)))
            return r.premium == true ? .premium : .refused(.noSubscription)
        } catch FunctionsError.httpError(_, let data) {
            struct Err: Decodable { let error: String? }
            if let refusal = refusal(code: (try? JSONDecoder().decode(Err.self, from: data))?.error) { return .refused(refusal) }
        } catch {}
        // Old behaviour when the new action is not there or fails: send each transaction on its own.
        var premium = false, found = false, refused: Refusal?, failed = false
        for jws in signed {
            found = true
            switch await send(jws) {
            case .accepted(let p): if p { premium = true }
            case .refused(let r): refused = r
            case .rejected, .retryLater: failed = true
            }
        }
        if premium { return .premium }
        if let refused { return .refused(refused) }
        if failed { return .failed }
        return found ? .refused(.noSubscription) : .none
    }

    /// Renewals, refunds, purchases approved later ("Ask to Buy") and purchases made on another device arrive here
    /// while the app runs; each goes to the server, then `onChange` refreshes the Premium status (also after a refund,
    /// when the answer is "not Premium"). A transaction is finished only after the server answered for good; a failed
    /// send stays open and is tried again on the next launch (`Transaction.unfinished`).
    static func listen(onChange: @escaping @Sendable () async -> Void) -> Task<Void, Never> {
        Task.detached {
            func handle(_ result: VerificationResult<Transaction>) async {
                guard case .verified(let t) = result, supabase.auth.currentUser != nil else { return }
                let sent = await send(result.jwsRepresentation)
                if sent.isFinal { await t.finish(); await onChange() }
            }
            for await result in Transaction.unfinished { await handle(result) }
            for await result in Transaction.updates { await handle(result) }
        }
    }
}
