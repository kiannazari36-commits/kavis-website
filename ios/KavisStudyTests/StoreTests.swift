import StoreKit
import StoreKitTest
import XCTest
@testable import KavisStudy

/// In-app purchase with Xcode's local App Store (KavisStudy.storekit): no real money, no App Store Connect.
final class StoreTests: XCTestCase {
    private var session: SKTestSession!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "KavisStudy")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
    }

    func testThePlansComeFromTheStoreInPaywallOrder() async throws {
        let products = await StoreAPI.products()
        XCTAssertEqual(products.map(\.id), StoreAPI.productIds)
        // Prices are the store's (displayPrice), never written in the app.
        XCTAssertTrue(products.allSatisfy { !$0.displayPrice.isEmpty })
        XCTAssertEqual(products[1].type, .nonRenewable) // the 5-month term
    }

    /// A purchase carries the account id. With TEST_RUNNER_KAVIS_UID / TEST_RUNNER_KAVIS_JWS_OUT set, the signed
    /// transaction is written to a file so it can be sent to the local Edge Function apple-purchase.
    func testPurchaseCarriesTheAccountId() async throws {
        let env = ProcessInfo.processInfo.environment
        let uid = env["KAVIS_UID"].flatMap(UUID.init(uuidString:)) ?? UUID()
        _ = try await session.buyProduct(identifier: "study.kavis.premium.month", options: [.appAccountToken(uid)])
        guard case .verified(let t)? = await Transaction.latest(for: "study.kavis.premium.month") else { return XCTFail("no transaction") }
        XCTAssertEqual(t.appAccountToken, uid)
        XCTAssertEqual(t.productID, "study.kavis.premium.month")
        if let out = env["KAVIS_JWS_OUT"], let jws = await Transaction.latest(for: "study.kavis.premium.month")?.jwsRepresentation {
            try jws.write(toFile: out, atomically: true, encoding: .utf8)
        }
    }
}
