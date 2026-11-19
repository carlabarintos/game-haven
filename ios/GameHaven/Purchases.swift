import StoreKit

/// Owns the Remove Ads state. Games and ad code only read adsRemoved.
/// The App Store's record decides; the stored flag keeps ads off between launches before that check is back.
@Observable
final class Purchases {
    static let shared = Purchases()
    static let removeAdsID = "com.gamehaven.removeads"

    private(set) var adsRemoved = UserDefaults.standard.bool(forKey: "adsRemoved") {
        didSet { UserDefaults.standard.set(adsRemoved, forKey: "adsRemoved") }
    }
    /// The Remove Ads product, with its local price, once the App Store has answered.
    private(set) var product: Product?
    var busy = false

    /// Called once at launch: checks what the player owns, then follows purchases made later or elsewhere
    /// (Ask to Buy approvals, Family Sharing, refunds).
    func start() async {
        product = try? await Product.products(for: [Self.removeAdsID]).first
        await refresh()
        for await update in Transaction.updates {
            if case .verified(let transaction) = update { await transaction.finish() }
            await refresh()
        }
    }

    /// Returns a message to show the player, or nil when there is nothing to say.
    func buy() async -> String? {
        guard let product else { return "The App Store can't be reached. Please try again later." }
        busy = true
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refresh()
                return "Thank you! Ads are gone for good."
            case .success(.unverified):
                return "The App Store couldn't confirm the purchase. Please try Restore Purchases."
            case .pending:
                return "Waiting for approval. Ads will go as soon as it's approved."
            case .userCancelled:
                return nil
            @unknown default:
                return nil
            }
        } catch {
            return "The purchase didn't go through. Please try again."
        }
    }

    func restore() async -> String {
        busy = true
        defer { busy = false }
        try? await AppStore.sync()  // throws if the player cancels the sign-in; the check below still runs
        await refresh()
        return adsRemoved ? "Remove Ads is restored." : "No earlier purchase was found for this Apple Account."
    }

    private func refresh() async {
        var owned = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement, transaction.productID == Self.removeAdsID { owned = true }
        }
        adsRemoved = owned
    }
}
