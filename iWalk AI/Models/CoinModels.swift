import Foundation

// MARK: - Coin Source

enum CoinSource: String, Codable, CaseIterable {
    case stepTier
    case personalGoal
    case streak
    case walkSession
    case journeyMilestone
    case challenge
    case badge
    case dailyReview
    case redemption

    var displayName: String {
        switch self {
        case .stepTier: "Step Goal"
        case .personalGoal: "Personal Goal"
        case .streak: "Daily Streak"
        case .walkSession: "Walk Complete"
        case .journeyMilestone: "Journey Milestone"
        case .challenge: "Challenge"
        case .badge: "Badge Unlock"
        case .dailyReview: "Daily Review"
        case .redemption: "Redemption"
        }
    }

    var icon: String {
        switch self {
        case .stepTier: "shoeprints.fill"
        case .personalGoal: "star.fill"
        case .streak: "flame.fill"
        case .walkSession: "figure.walk"
        case .journeyMilestone: "mappin.and.ellipse"
        case .challenge: "trophy.fill"
        case .badge: "medal.fill"
        case .dailyReview: "moon.stars.fill"
        case .redemption: "gift.fill"
        }
    }
}

// MARK: - Coin Transaction

struct CoinTransaction: Identifiable, Codable {
    let id: UUID
    let amount: Int
    let source: CoinSource
    let description: String
    let timestamp: Date

    init(amount: Int, source: CoinSource, description: String, timestamp: Date = .now) {
        self.id = UUID()
        self.amount = amount
        self.source = source
        self.description = description
        self.timestamp = timestamp
    }
}

// MARK: - Coin Account

struct CoinAccount: Codable {
    var balance: Int
    var lifetimeEarned: Int
    var lifetimeSpent: Int

    static let empty = CoinAccount(balance: 0, lifetimeEarned: 0, lifetimeSpent: 0)

    mutating func earn(_ amount: Int) {
        balance += amount
        lifetimeEarned += amount
    }

    mutating func spend(_ amount: Int) -> Bool {
        guard balance >= amount else { return false }
        balance -= amount
        lifetimeSpent += amount
        return true
    }
}
