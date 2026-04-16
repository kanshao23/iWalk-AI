import StoreKit
import SwiftUI

@MainActor
@Observable
final class StoreKitManager {
    static let shared = StoreKitManager()

    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var isLoading = false
    var errorMessage: String?

    private let productIDs = ["kanshaous.iwalk.weekly", "kanshaous.iwalk.yearly"]
    private var transactionListenerTask: Task<Void, Error>?
    private let subscriptionFlagKey = "hasSubscribed"

    private init() {
        transactionListenerTask = listenForTransactions()
        Task { await refreshEntitlements() }
    }

    #if DEBUG
    var debugUnlockPro = false
    #endif

    var isPremium: Bool {
        #if DEBUG
        if debugUnlockPro { return true }
        #endif
        return !purchasedProductIDs.isEmpty
    }

    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        do {
            products = try await Product.products(for: productIDs)
            products.sort { $0.price < $1.price }
        } catch {
            errorMessage = "Could not load products. Check your connection."
        }
        isLoading = false
        await updatePurchasedProducts()
    }

    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updatePurchasedProducts()
                isLoading = false
                return true
            case .userCancelled, .pending:
                isLoading = false
                return false
            @unknown default:
                isLoading = false
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    func restore() async {
        isLoading = true
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func refreshEntitlements() async {
        await updatePurchasedProducts()
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if let transaction = try? await self.checkVerified(result) {
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                }
            }
        }
    }

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            }
        }
        purchasedProductIDs = purchased
        UserDefaults.standard.set(!purchased.isEmpty, forKey: subscriptionFlagKey)
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
