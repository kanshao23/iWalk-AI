import SwiftUI

@Observable
final class CoinViewModel {
    var account: CoinAccount
    var transactions: [CoinTransaction]
    var todayTiers: [StepTier]
    var personalGoal: PersonalGoal

    // Toast state
    var showCoinToast = false
    var lastEarnedAmount = 0
    var lastEarnedSource: CoinSource = .stepTier

    private let accountKey = "iw_coin_account"
    private let transactionsKey = "iw_coin_transactions"
    private let todayTiersKey = "iw_today_tiers"
    private let tiersDateKey = "iw_tiers_date"
    private let personalGoalKey = "iw_personal_goal"

    init() {
        if let data = UserDefaults.standard.data(forKey: accountKey),
           let saved = try? JSONDecoder().decode(CoinAccount.self, from: data) {
            self.account = saved
        } else {
            self.account = .empty
        }

        if let data = UserDefaults.standard.data(forKey: transactionsKey),
           let saved = try? JSONDecoder().decode([CoinTransaction].self, from: data) {
            self.transactions = saved
        } else {
            self.transactions = []
        }

        let savedDate = UserDefaults.standard.string(forKey: tiersDateKey) ?? ""
        let todayStr = Self.todayString()
        if savedDate == todayStr,
           let data = UserDefaults.standard.data(forKey: todayTiersKey),
           let saved = try? JSONDecoder().decode([StepTier].self, from: data) {
            self.todayTiers = saved
        } else {
            self.todayTiers = StepTier.allTiers
        }

        if let data = UserDefaults.standard.data(forKey: personalGoalKey),
           let saved = try? JSONDecoder().decode(PersonalGoal.self, from: data) {
            self.personalGoal = saved
        } else {
            self.personalGoal = .mock
        }
    }

    // MARK: - Earn

    @discardableResult
    func earn(amount: Int, source: CoinSource, description: String) -> CoinTransaction {
        let tx = CoinTransaction(amount: amount, source: source, description: description)
        account.earn(amount)
        transactions.insert(tx, at: 0)

        if transactions.count > 200 {
            transactions = Array(transactions.prefix(200))
        }

        lastEarnedAmount = amount
        lastEarnedSource = source
        Task { @MainActor in
            ToastQueue.shared.enqueue(amount: amount, source: source)
        }

        save()
        return tx
    }

    // MARK: - Spend

    func spend(amount: Int, description: String) -> Bool {
        guard account.spend(amount) else { return false }
        let tx = CoinTransaction(amount: -amount, source: .redemption, description: description)
        transactions.insert(tx, at: 0)
        save()
        return true
    }

    // MARK: - Shop

    private let unlockedThemesKey = "iw_unlocked_themes"

    var unlockedThemes: Set<String> {
        get {
            let saved = UserDefaults.standard.stringArray(forKey: unlockedThemesKey) ?? []
            return Set(saved)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: unlockedThemesKey)
        }
    }

    func unlockTheme(_ themeId: String, streakVM: StreakViewModel) -> Bool {
        if themeId == "freeze_card" {
            guard spend(amount: 20, description: "Purchased freeze card") else { return false }
            streakVM.addFreezeCard()
            return true
        }
        guard !unlockedThemes.contains(themeId) else { return false }
        guard spend(amount: 50, description: "Unlocked journey theme: \(themeId)") else { return false }
        var themes = unlockedThemes
        themes.insert(themeId)
        unlockedThemes = themes
        return true
    }

    // MARK: - Step Tier Checks

    @discardableResult
    func checkStepTiers(currentSteps: Int) -> [Int] {
        var newlyReached: [Int] = []

        for i in todayTiers.indices {
            if !todayTiers[i].isReached && currentSteps >= todayTiers[i].stepsRequired {
                todayTiers[i].isReached = true
                todayTiers[i].isClaimed = true
                newlyReached.append(todayTiers[i].id)
                earn(
                    amount: todayTiers[i].coinReward,
                    source: .stepTier,
                    description: "Tier \(todayTiers[i].id): \(todayTiers[i].stepsRequired.formatted()) steps"
                )
            }
        }

        if !personalGoal.isReached && currentSteps >= personalGoal.targetSteps {
            personalGoal.isReached = true
            earn(
                amount: personalGoal.coinReward,
                source: .personalGoal,
                description: "Personal goal: \(personalGoal.targetSteps.formatted()) steps"
            )
            savePersonalGoal()
        }

        saveTiers()
        return newlyReached
    }

    // MARK: - Today Stats

    var todayEarnings: Int {
        let todayStart = Calendar.current.startOfDay(for: .now)
        return transactions
            .filter { $0.timestamp >= todayStart && $0.amount > 0 }
            .reduce(0) { $0 + $1.amount }
    }

    var highestTierReached: Int {
        todayTiers.filter(\.isReached).map(\.id).max() ?? 0
    }

    func setPersonalGoal(targetSteps: Int) {
        personalGoal = PersonalGoal.from(target: targetSteps)
        savePersonalGoal()
    }

    func resetAllData() {
        account = .empty
        transactions = []
        todayTiers = StepTier.allTiers
        personalGoal = .mock
        save()
        saveTiers()
        savePersonalGoal()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(account) {
            UserDefaults.standard.set(data, forKey: accountKey)
        }
        if let data = try? JSONEncoder().encode(transactions) {
            UserDefaults.standard.set(data, forKey: transactionsKey)
        }
    }

    private func saveTiers() {
        if let data = try? JSONEncoder().encode(todayTiers) {
            UserDefaults.standard.set(data, forKey: todayTiersKey)
        }
        UserDefaults.standard.set(Self.todayString(), forKey: tiersDateKey)
    }

    private func savePersonalGoal() {
        if let data = try? JSONEncoder().encode(personalGoal) {
            UserDefaults.standard.set(data, forKey: personalGoalKey)
        }
    }

    private static func todayString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: .now)
    }
}
