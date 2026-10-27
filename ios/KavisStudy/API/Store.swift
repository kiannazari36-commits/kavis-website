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

    enum BuyResult { case premium, pending, cancelled, failed }

    /// Buys a plan. The purchase carries the student's account id (appAccountToken), so the server can only give it
    /// to this account.
    static func buy(_ product: Product) async -> BuyResult {
        guard let uid = supabase.auth.currentUser?.id else { return .failed }
        do {
            switch try await product.purchase(options: [.appAccountToken(uid)]) {
            case .success(let result):
                guard case .verified(let t) = result, await send(result.jwsRepresentation) else { return .failed }
                await t.finish()
                return .premium
            case .pending: return .pending
            case .userCancelled: return .cancelled
            @unknown default: return .failed
            }
        } catch {
            return .failed
        }
    }

    /// Sends a signed transaction to the server; true when the account is Premium after it.
    @discardableResult
    static func send(_ signedTransaction: String) async -> Bool {
        struct Body: Encodable { let action = "purchase"; let signed_transaction: String }
        struct Res: Decodable { let premium: Bool }
        let r: Res? = try? await supabase.functions.invoke("apple-purchase", options: FunctionInvokeOptions(body: Body(signed_transaction: signedTransaction)))
        return r?.premium == true
    }

    /// "Satın alımları geri yükle": asks the App Store for this Apple Account's purchases and sends them to the server.
    /// nil = the App Store could not be reached; false = nothing to restore.
    static func restore() async -> Bool? {
        guard (try? await AppStore.sync()) != nil else { return nil }
        var premium = false
        for await result in Transaction.currentEntitlements {
            if case .verified = result, await send(result.jwsRepresentation) { premium = true }
        }
        return premium
    }

    /// Renewals, purchases approved later ("Ask to Buy") and purchases made on another device arrive here while the
    /// app runs; each goes to the server, then `onChange` refreshes the Premium status.
    static func listen(onChange: @escaping @Sendable () async -> Void) -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                guard case .verified(let t) = result else { continue }
                if supabase.auth.currentUser != nil, await send(result.jwsRepresentation) { await onChange() }
                await t.finish()
            }
        }
    }
}
