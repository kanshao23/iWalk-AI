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

    var price: String {
        switch self {
        case .weekly: "$2.99"
        case .yearly: "$0.77"
        }
    }

    var period: String { "/week" }

    var perWeekPrice: String? {
        switch self {
        case .weekly: nil
        case .yearly: "$39.99/yr billed annually"
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
    var showRetentionOffer = false
    var retentionPrice = "$29.99/year"
    var purchaseError: String?

    private let hasShownRetentionKey = "iw_has_shown_retention"

    var isPurchasing: Bool { StoreKitManager.shared.isLoading }
    var isPremium: Bool { StoreKitManager.shared.isPremium }

    let features: [(icon: String, title: String, description: String)] = [
        ("brain.head.profile", "AI Health Insights", "Personalized health analysis powered by AI"),
        ("figure.walk", "Smart Walking Coach", "Real-time coaching that adapts to your pace"),
        ("chart.line.uptrend.xyaxis", "Advanced Analytics", "Deep health trends and projections"),
        ("trophy.fill", "Challenges & Badges", "Compete with friends and earn achievements"),
        ("heart.text.clipboard", "Health Reports", "Weekly AI-generated wellness reports"),
    ]

    let socialProof = "Join 25,000+ walkers already improving their health"

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

    func dismiss() {
        let hasShown = UserDefaults.standard.bool(forKey: hasShownRetentionKey)
        if !hasShown && !isPremium {
            UserDefaults.standard.set(true, forKey: hasShownRetentionKey)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showRetentionOffer = true
            }
        }
    }

    func declineRetention() {
        showRetentionOffer = false
    }
}
