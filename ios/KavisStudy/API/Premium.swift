import Foundation

/// Premium. In the iPhone app Premium is bought only with Apple in-app purchase (StoreKit, later).
/// Prices are never written here: Apple sets the local price per country and StoreKit returns it.
enum PremiumAPI {
    private struct Offer: Decodable {
        let rows: [CompareRow]
        let plans: [PremiumPlan]
    }

    private static let offer: Offer = MockData.load("mock-premium")

    static func getOffer() async -> (rows: [CompareRow], plans: [PremiumPlan]) {
        await fakeRequest((offer.rows, offer.plans), ms: 120)
    }

    /// Mock: Premium status of the account. A real server will check the Apple subscription,
    /// so Premium bought on the iPhone also unlocks the web. Test switch: `-kavis.premium 1`.
    static func isPremium() -> Bool {
        UserDefaults.standard.string(forKey: "kavis.premium") == "1"
    }
}
