import SwiftUI

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

    var period: String {
        "/week"
    }

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
}

@Observable
final class PaywallViewModel {
    var selectedPlan: PricingPlan = .yearly
    var isPurchasing = false
    var showRetentionOffer = false
    var retentionPrice = "$29.99/year"

    let features: [(icon: String, title: String, description: String)] = [
        ("brain.head.profile", "AI Health Insights", "Personalized health analysis powered by AI"),
        ("figure.walk", "Smart Walking Coach", "Real-time coaching that adapts to your pace"),
        ("chart.line.uptrend.xyaxis", "Advanced Analytics", "Deep health trends and projections"),
        ("trophy.fill", "Challenges & Badges", "Compete with friends and earn achievements"),
        ("heart.text.clipboard", "Health Reports", "Weekly AI-generated wellness reports"),
    ]

    let socialProof = "Join 25,000+ walkers already improving their health"

    func purchase() {
        isPurchasing = true
        // StoreKit purchase integration placeholder
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.isPurchasing = false
        }
    }

    func restore() {
        // StoreKit restore purchases placeholder
    }

    func dismiss() {
        // Show retention offer on first dismiss attempt
        if !showRetentionOffer {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showRetentionOffer = true
            }
        }
    }

    func declineRetention() {
        showRetentionOffer = false
    }
}
