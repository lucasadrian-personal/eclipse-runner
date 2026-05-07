import StoreKit
import SwiftUI

// MARK: - ShopIAPManager
// Handles all In-App Purchases using StoreKit 2

typealias SKTransaction = StoreKit.Transaction

@MainActor
final class ShopIAPManager: ObservableObject {

    static let shared = ShopIAPManager()

    // Product IDs
    static let skinProductIDs: Set<String> = [
        "com.lucasadrian.eclipserunner.skin.forest",
        "com.lucasadrian.eclipserunner.skin.ghost",
        "com.lucasadrian.eclipserunner.skin.galactic"
    ]
    static let shieldProductIDs: Set<String> = [
        "com.lucasadrian.eclipserunner.shields1",
        "com.lucasadrian.eclipserunner.shields5"
    ]
    static let allProductIDs: Set<String> = skinProductIDs.union(shieldProductIDs)

    // Published state
    @Published var products: [String: Product] = [:]
    @Published var purchasedIDs: Set<String> = []
    @Published var isPurchasing: Bool = false
    @Published var purchaseError: String? = nil

    private var updateListenerTask: Task<Void, Never>? = nil

    private init() {
        updateListenerTask = listenForTransactionUpdates()
        Task { await loadProducts() }
        Task { await restorePurchases() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load products from App Store Connect
    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: Self.allProductIDs)
            for product in fetched {
                products[product.id] = product
            }
        } catch {
            NSLog("[IAP] Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase
    func purchase(productID: String, store: GameStore) async {
        guard let product = products[productID] else {
            purchaseError = "Product not available. Please try again later."
            return
        }
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await fulfil(transaction: transaction, store: store)
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
            NSLog("[IAP] Purchase error: \(error)")
        }
    }

    // MARK: - Restore purchases (no store reference needed for entitlements check)
    func restorePurchases() async {
        for await result in SKTransaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                purchasedIDs.insert(transaction.productID)
                await transaction.finish()
            }
        }
    }

    func restorePurchases(store: GameStore) async {
        for await result in SKTransaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                purchasedIDs.insert(transaction.productID)
                if Self.skinProductIDs.contains(transaction.productID) {
                    store.grantSkin(transaction.productID)
                }
                await transaction.finish()
            }
        }
    }

    // MARK: - Fulfil after verified purchase
    private func fulfil(transaction: SKTransaction, store: GameStore) async {
        purchasedIDs.insert(transaction.productID)

        if Self.skinProductIDs.contains(transaction.productID) {
            store.grantSkin(transaction.productID)
        } else {
            switch transaction.productID {
            case "com.lucasadrian.eclipserunner.shields1": store.addShields(3)
            case "com.lucasadrian.eclipserunner.shields5": store.addShields(10)
            default: break
            }
        }
    }

    // MARK: - Transaction listener
    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in SKTransaction.updates {
                guard let self else { return }
                if let transaction = try? self.checkVerified(result) {
                    // Fulfil without a store reference — grant is handled on next restorePurchases
                    await MainActor.run { self.purchasedIDs.insert(transaction.productID) }
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Helpers
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value): return value
        }
    }

    func priceString(for productID: String) -> String {
        products[productID]?.displayPrice ?? ""
    }

    func isOwned(_ productID: String) -> Bool {
        purchasedIDs.contains(productID)
    }
}
