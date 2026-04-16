import SwiftUI
import StoreKit

enum PricingPlan: String, CaseIterable, Identifiable {
    case weekly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: "Weekly"
        case .yearly: "Annual"
        }
    }

    /// Fallback billed amount shown before StoreKit products load.
    var fallbackBilledPrice: String {
        switch self {
        case .weekly: "$2.99"
        case .yearly: "$39.99"
        }
    }

    /// Billing period label displayed next to the main price.
    var billedPeriod: String {
        switch self {
        case .weekly: "/week"
        case .yearly: "/yr"
        }
    }

    /// Secondary per-week equivalent shown below the main price (annual only).
    var weeklyEquivalent: String? {
        switch self {
        case .weekly: nil
        case .yearly: "≈ $0.77 / week"
        }
    }

    var savingsBadge: String? {
        switch self {
        case .weekly: nil
        case .yearly: "SAVE 74%"
        }
    }

    var productID: String {
        switch self {
        case .weekly: "kanshaous.iwalk.weekly"
        case .yearly: "kanshaous.iwalk.yearly"
        }
    }
}

@Observable
final class PaywallViewModel {
    var selectedPlan: PricingPlan = .yearly
    var purchaseError: String?

    var isPurchasing: Bool { StoreKitManager.shared.isLoading }
    var isPremium: Bool { StoreKitManager.shared.isPremium }

    let features: [(icon: String, title: String, description: String)] = [
        ("figure.walk", "Step Tiers & Coin Rewards", "Hit 5 daily step tiers and earn iWalk Coins instantly"),
        ("map.fill", "Virtual Journey", "Walk New York to Los Angeles — 4,500 km across America"),
        ("brain.head.profile", "AI Walking Coach", "Personalized daily advice based on your real step progress"),
        ("flame.fill", "Streak Protection", "Earn freeze cards every 7 days to protect your streak"),
        ("trophy.fill", "Badges & Milestones", "Unlock achievements at 7, 14, 30, 60 and 100-day streaks"),
    ]

    let socialProof = "Every step earns a reward."

    /// Returns the StoreKit-formatted price for a plan, falling back to the hardcoded value.
    func displayPrice(for plan: PricingPlan) -> String {
        StoreKitManager.shared.products
            .first(where: { $0.id == plan.productID })?.displayPrice
            ?? plan.fallbackBilledPrice
    }

    func loadProducts() async {
        await StoreKitManager.shared.loadProducts()
    }

    func purchase() async -> Bool {
        purchaseError = nil
        let storeKit = StoreKitManager.shared
        guard let product = storeKit.products.first(where: { $0.id == selectedPlan.productID }) else {
            purchaseError = "Product not available. Please try again."
            return false
        }
        let success = await storeKit.purchase(product)
        if let error = storeKit.errorMessage {
            purchaseError = error
        }
        return success
    }

    func restore() async {
        purchaseError = nil
        await StoreKitManager.shared.restore()
        if let error = StoreKitManager.shared.errorMessage {
            purchaseError = error
        }
    }

}
