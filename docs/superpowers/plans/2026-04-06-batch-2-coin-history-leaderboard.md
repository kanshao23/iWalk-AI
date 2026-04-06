# Batch 2: Coin Shop + Walk History + Local Leaderboard Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give coins a real spending loop, add a walk history page, and replace the fake social leaderboard with an honest "this week vs last week" comparison.

**Architecture:** Two new View files (`CoinShopView`, `WalkHistoryView`). `BadgesViewModel` gets a leaderboard replacement. `ActiveWalkViewModel` gains WalkSession persistence. No new ViewModels needed — lean into existing `CoinViewModel`, `StreakViewModel`, `BadgesViewModel`.

**Tech Stack:** SwiftUI, @Observable, UserDefaults (persistence), HealthKit (previous week steps)

---

## File Map

| Action | File |
|--------|------|
| Create | `iWalk AI/Views/CoinShopView.swift` |
| Create | `iWalk AI/Views/WalkHistoryView.swift` |
| Modify | `iWalk AI/ViewModels/CoinViewModel.swift` — shop items |
| Modify | `iWalk AI/ViewModels/StreakViewModel.swift` — `addFreezeCard()` |
| Modify | `iWalk AI/ViewModels/ActiveWalkViewModel.swift` — persist WalkSession |
| Modify | `iWalk AI/ViewModels/BadgesViewModel.swift` — local leaderboard data |
| Modify | `iWalk AI/Views/BadgesView.swift` — leaderboard UI + shop button |
| Modify | `iWalk AI/Views/DashboardView.swift` — history button |
| Modify | `iWalk AI/Services/HealthKitManager.swift` — `fetchPreviousWeekSteps()` |

---

## Task 1: Persist Walk Sessions

**Files:**
- Modify: `iWalk AI/ViewModels/ActiveWalkViewModel.swift`

Walk history requires WalkSession to be saved. Currently `endWalk()` creates a session but never writes it.

- [ ] **Step 1: Add persistence to `ActiveWalkViewModel.endWalk()`**

Add this helper at the bottom of `ActiveWalkViewModel`, before the closing brace:

```swift
private static let historyKey = "iw_walk_history"

static func saveSession(_ session: WalkSession) {
    var history = loadHistory()
    history.insert(session, at: 0)
    // Keep last 365 sessions
    if history.count > 365 {
        history = Array(history.prefix(365))
    }
    if let data = try? JSONEncoder().encode(history) {
        UserDefaults.standard.set(data, forKey: historyKey)
    }
}

static func loadHistory() -> [WalkSession] {
    guard let data = UserDefaults.standard.data(forKey: historyKey),
          let history = try? JSONDecoder().decode([WalkSession].self, from: data) else {
        return []
    }
    return history
}
```

In `endWalk()`, add after `invalidateAll()` and the notification post:

```swift
func endWalk() {
    invalidateAll()
    NotificationCenter.default.post(name: .walkDidEnd, object: nil)
    let session = WalkSession(
        startTime: startTime,
        endTime: .now,
        steps: sessionSteps,
        calories: sessionCalories,
        distanceKm: sessionDistanceKm,
        elapsedSeconds: elapsedSeconds,
        dailyGoal: dailyGoal,
        stepsBeforeWalk: stepsBeforeWalk,
        averageHeartRate: currentHeartRate
    )
    ActiveWalkViewModel.saveSession(session)   // Add this line
    withAnimation(.easeInOut(duration: 0.4)) {
        phase = .summary(session)
    }
}
```

- [ ] **Step 2: Verify `WalkSession` conforms to `Codable`**

Open `iWalk AI/Models/WalkModels.swift` and check `WalkSession`. If it doesn't have `Codable`, add it:

```swift
struct WalkSession: Codable, Identifiable {
    // existing fields
}
```

- [ ] **Step 3: Build to verify**

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export PATH="$DEVELOPER_DIR/usr/bin:$PATH"
xcodebuild build \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  2>&1 | xcbeautify --quiet
```

Expected: Build Succeeded

- [ ] **Step 4: Commit**

```bash
git add "iWalk AI/ViewModels/ActiveWalkViewModel.swift" \
        "iWalk AI/Models/WalkModels.swift"
git commit -m "feat: persist walk sessions to UserDefaults for history page"
```

---

## Task 2: Walk History View

**Files:**
- Create: `iWalk AI/Views/WalkHistoryView.swift`
- Modify: `iWalk AI/Views/DashboardView.swift`

- [ ] **Step 1: Create `WalkHistoryView.swift`**

```swift
import SwiftUI

struct WalkHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    private let history: [WalkSession]

    init() {
        self.history = ActiveWalkViewModel.loadHistory()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.iwSurface.ignoresSafeArea()

                if history.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("Walk History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(IWFont.labelLarge())
                        .foregroundStyle(Color.iwPrimary)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.walk.circle")
                .font(.system(size: 56))
                .foregroundStyle(Color.iwOutlineVariant)
            Text("No walks yet")
                .font(IWFont.titleMedium())
                .foregroundStyle(Color.iwOnSurface)
            Text("Complete your first walk to see it here.")
                .font(IWFont.bodyMedium())
                .foregroundStyle(Color.iwOutline)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(groupedHistory, id: \.key) { group in
                    Section {
                        ForEach(group.sessions) { session in
                            SessionRow(session: session)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                        }
                    } header: {
                        Text(group.key)
                            .font(IWFont.labelLarge())
                            .foregroundStyle(Color.iwOutline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.iwSurface)
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }

    private var groupedHistory: [(key: String, sessions: [WalkSession])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let grouped = Dictionary(grouping: history) { session in
            formatter.string(from: session.startTime)
        }
        return grouped
            .sorted { a, b in
                guard let aDate = history.first(where: { formatter.string(from: $0.startTime) == a.key })?.startTime,
                      let bDate = history.first(where: { formatter.string(from: $0.startTime) == b.key })?.startTime
                else { return false }
                return aDate > bDate
            }
            .map { (key: $0.key, sessions: $0.value.sorted { $0.startTime > $1.startTime }) }
    }
}

private struct SessionRow: View {
    let session: WalkSession
    @State private var isExpanded = false

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.iwPrimaryContainer)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "figure.walk")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.iwPrimary)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(session.steps.formatted()) steps")
                            .font(IWFont.titleSmall())
                            .foregroundStyle(Color.iwOnSurface)
                        Text(timeFormatter.string(from: session.startTime))
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwOutline)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(session.formattedDuration)
                            .font(IWFont.titleSmall())
                            .foregroundStyle(Color.iwOnSurface)
                        Text(String(format: "%.2f km", session.distanceKm))
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwOutline)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.iwOutlineVariant)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                HStack(spacing: 0) {
                    detailItem(icon: "flame.fill", value: "\(session.calories)", label: "kcal")
                    detailItem(icon: "speedometer", value: session.paceFormatted, label: "min/km")
                    if session.averageHeartRate > 0 {
                        detailItem(icon: "heart.fill", value: "\(session.averageHeartRate)", label: "bpm")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color.iwSurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func detailItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.iwPrimary)
            Text(value)
                .font(IWFont.labelLarge())
                .foregroundStyle(Color.iwOnSurface)
            Text(label)
                .font(IWFont.labelSmall())
                .foregroundStyle(Color.iwOutline)
        }
        .frame(maxWidth: .infinity)
    }
}
```

**Note:** `session.formattedDuration` and `session.paceFormatted` must exist on `WalkSession`. Check `WalkModels.swift` — if missing, add them:

```swift
// In WalkSession:
var formattedDuration: String {
    let mins = elapsedSeconds / 60
    let secs = elapsedSeconds % 60
    return String(format: "%d:%02d", mins, secs)
}

var paceFormatted: String {
    guard distanceKm > 0.01 else { return "--:--" }
    let pace = (Double(elapsedSeconds) / 60.0) / distanceKm
    let mins = Int(pace)
    let secs = Int((pace - Double(mins)) * 60)
    return String(format: "%d:%02d", mins, secs)
}
```

- [ ] **Step 2: Add history button to DashboardView**

In `DashboardView.swift`, find the weekly activity chart section. Add a "View All" button to its header:

```swift
SectionHeader(title: "Weekly Activity") {
    Button("View All") {
        vm.showHistory = true
    }
    .font(IWFont.labelMedium())
    .foregroundStyle(Color.iwPrimary)
}
```

Then add the sheet presentation (near the other `.sheet` modifiers):

```swift
.sheet(isPresented: $vm.showHistory) {
    WalkHistoryView()
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  2>&1 | xcbeautify --quiet
```

Expected: Build Succeeded

- [ ] **Step 4: Commit**

```bash
git add "iWalk AI/Views/WalkHistoryView.swift" \
        "iWalk AI/Models/WalkModels.swift" \
        "iWalk AI/Views/DashboardView.swift"
git commit -m "feat: walk history page with expandable session details"
```

---

## Task 3: Coin Shop

**Files:**
- Create: `iWalk AI/Views/CoinShopView.swift`
- Modify: `iWalk AI/ViewModels/StreakViewModel.swift`
- Modify: `iWalk AI/Views/BadgesView.swift`

- [ ] **Step 1: Add `addFreezeCard()` to `StreakViewModel`**

In `StreakViewModel.swift`, add after `useFreezeCard()`:

```swift
func addFreezeCard() {
    streak.freezeCardsRemaining += 1
    save()
}
```

- [ ] **Step 2: Add unlocked journey themes to `CoinViewModel`**

In `CoinViewModel.swift`, add stored property and persistence after `private let personalGoalKey`:

```swift
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
```

- [ ] **Step 3: Create `CoinShopView.swift`**

```swift
import SwiftUI

struct CoinShopView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var coinVM: CoinViewModel
    var streakVM: StreakViewModel

    struct ShopItem {
        let id: String
        let icon: String
        let title: String
        let description: String
        let price: Int
        let isConsumable: Bool
    }

    private let items: [ShopItem] = [
        ShopItem(id: "freeze_card", icon: "snowflake", title: "Freeze Card",
                 description: "Protect your streak if you miss a day.", price: 20, isConsumable: true),
        ShopItem(id: "theme_aurora", icon: "sparkles", title: "Aurora Journey",
                 description: "Northern lights color theme for your journey map.", price: 50, isConsumable: false),
        ShopItem(id: "theme_forest", icon: "leaf.fill", title: "Forest Journey",
                 description: "Deep green forest theme for your journey.", price: 50, isConsumable: false),
        ShopItem(id: "theme_galaxy", icon: "moon.stars.fill", title: "Galaxy Journey",
                 description: "Cosmic deep-space theme for your journey.", price: 50, isConsumable: false),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.iwSurface.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Balance header
                        HStack(spacing: 8) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.iwPrimaryFixed)
                            Text("\(coinVM.account.balance) coins")
                                .font(IWFont.titleLarge())
                                .foregroundStyle(Color.iwOnSurface)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.iwSurfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)

                        // Items
                        VStack(spacing: 12) {
                            ForEach(items, id: \.id) { item in
                                ShopItemRow(
                                    item: item,
                                    balance: coinVM.account.balance,
                                    isOwned: !item.isConsumable && coinVM.unlockedThemes.contains(item.id),
                                    onPurchase: {
                                        _ = coinVM.unlockTheme(item.id, streakVM: streakVM)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Coin Shop")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(IWFont.labelLarge())
                        .foregroundStyle(Color.iwPrimary)
                }
            }
        }
    }
}

private struct ShopItemRow: View {
    let item: CoinShopView.ShopItem
    let balance: Int
    let isOwned: Bool
    let onPurchase: () -> Void

    private var canAfford: Bool { balance >= item.price }

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.iwSecondaryFixed)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: item.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(Color.iwSecondary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(IWFont.titleSmall())
                    .foregroundStyle(Color.iwOnSurface)
                Text(item.description)
                    .font(IWFont.bodySmall())
                    .foregroundStyle(Color.iwOutline)
                    .lineLimit(2)
            }

            Spacer()

            if isOwned {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.iwPrimary)
            } else {
                Button(action: onPurchase) {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 12))
                        Text("\(item.price)")
                            .font(IWFont.labelLarge())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(canAfford ? Color.iwPrimary : Color.iwSurfaceContainerHigh)
                    .foregroundStyle(canAfford ? Color.white : Color.iwOutline)
                    .clipShape(Capsule())
                }
                .disabled(!canAfford)
            }
        }
        .padding(14)
        .background(Color.iwSurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 4: Add shop button to BadgesView**

In `BadgesView.swift`, find the coin balance display or header area. Add a shop button. Look for the existing header — likely near `CoinBalanceView`. Add:

```swift
Button {
    showCoinShop = true
} label: {
    Image(systemName: "storefront.fill")
        .font(.system(size: 16))
        .foregroundStyle(Color.iwPrimary)
        .frame(width: 32, height: 32)
        .background(Color.iwPrimaryContainer)
        .clipShape(Circle())
}
```

Add `@State private var showCoinShop = false` at the top of `BadgesView`.

Add the sheet:
```swift
.sheet(isPresented: $showCoinShop) {
    CoinShopView(coinVM: coinVM, streakVM: streakVM)
}
```

Read `BadgesView.swift` first to find the exact injection point for `coinVM` and `streakVM` (they may be `@Environment` or passed as parameters).

- [ ] **Step 5: Build to verify**

```bash
xcodebuild build \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  2>&1 | xcbeautify --quiet
```

Expected: Build Succeeded

- [ ] **Step 6: Commit**

```bash
git add "iWalk AI/Views/CoinShopView.swift" \
        "iWalk AI/ViewModels/CoinViewModel.swift" \
        "iWalk AI/ViewModels/StreakViewModel.swift" \
        "iWalk AI/Views/BadgesView.swift"
git commit -m "feat: coin shop — spend coins on freeze cards and journey themes"
```

---

## Task 4: Local Leaderboard (This Week vs Last Week)

**Files:**
- Modify: `iWalk AI/Services/HealthKitManager.swift`
- Modify: `iWalk AI/ViewModels/BadgesViewModel.swift`
- Modify: `iWalk AI/Views/BadgesView.swift`

- [ ] **Step 1: Add `fetchPreviousWeekSteps()` to `HealthKitManager`**

In `HealthKitManager.swift`, add after `fetchWeeklySteps()`:

```swift
func fetchPreviousWeekSteps() async -> [DailyStats] {
    guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    guard let endDate = calendar.date(byAdding: .day, value: -7, to: today),
          let startDate = calendar.date(byAdding: .day, value: -13, to: today) else { return [] }

    return await withCheckedContinuation { continuation in
        var interval = DateComponents()
        interval.day = 1

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate),
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            var daily: [DailyStats] = []
            results?.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                let steps = Int(stats.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                daily.append(DailyStats(
                    date: stats.startDate,
                    steps: steps,
                    calories: steps / 20,
                    distanceKm: Double(steps) / 1400.0,
                    activeMinutes: steps / 200,
                    heartRate: nil
                ))
            }
            continuation.resume(returning: daily)
        }
        self.store.execute(query)
    }
}
```

- [ ] **Step 2: Add local comparison data to `BadgesViewModel`**

Replace the `leaderboard` and `totalParticipants` in `BadgesViewModel.swift` with:

```swift
// Remove:
// var leaderboard = LeaderboardEntry.mockEntries
// var totalParticipants: Int { 25_000 }

// Add:
var thisWeekDaily: [DailyStats] = []
var lastWeekDaily: [DailyStats] = []
var isLoadingComparison = false

var thisWeekAvg: Int {
    guard !thisWeekDaily.isEmpty else { return 0 }
    return thisWeekDaily.map(\.steps).reduce(0, +) / thisWeekDaily.count
}

var lastWeekAvg: Int {
    guard !lastWeekDaily.isEmpty else { return 0 }
    return lastWeekDaily.map(\.steps).reduce(0, +) / lastWeekDaily.count
}

var weekOverWeekPercent: Int {
    guard lastWeekAvg > 0 else { return 0 }
    return Int(((Double(thisWeekAvg) - Double(lastWeekAvg)) / Double(lastWeekAvg)) * 100)
}

var comparisonMessage: String {
    let pct = weekOverWeekPercent
    if pct > 0 {
        return "比上周多走了 \(pct)%，保持！"
    } else if pct < 0 {
        return "比上周少了 \(abs(pct))%，今天发力！"
    } else {
        return "与上周持平，继续加油！"
    }
}

@MainActor
func loadComparisonData() async {
    let healthKit = HealthKitManager.shared
    guard healthKit.isAuthorized else { return }
    isLoadingComparison = true
    async let thisWeek = healthKit.fetchWeeklySteps()
    async let lastWeek = healthKit.fetchPreviousWeekSteps()
    thisWeekDaily = await thisWeek
    lastWeekDaily = await lastWeek
    isLoadingComparison = false
}
```

Keep `selectedBadge`, `badges`, `challenges`, and animation state unchanged.

- [ ] **Step 3: Replace leaderboard card in `BadgesView`**

In `BadgesView.swift`, find the leaderboard card section and replace with the local comparison card. Read the file first to identify the exact location, then replace the leaderboard UI with:

```swift
// Local comparison card
InfoCard(backgroundColor: .iwSurfaceContainerLow) {
    VStack(alignment: .leading, spacing: 14) {
        HStack {
            Text("本周 vs 上周")
                .font(IWFont.titleSmall())
                .foregroundStyle(Color.iwOnSurface)
            Spacer()
            if badgesVM.isLoadingComparison {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }

        // Avg steps comparison
        HStack(spacing: 0) {
            comparisonStat(
                label: "本周均",
                value: badgesVM.thisWeekAvg.formatted(),
                color: .iwPrimary
            )
            Divider().frame(height: 40)
            comparisonStat(
                label: "上周均",
                value: badgesVM.lastWeekAvg.formatted(),
                color: .iwOutline
            )
            Spacer()
            // Trend indicator
            let pct = badgesVM.weekOverWeekPercent
            HStack(spacing: 4) {
                Image(systemName: pct >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundStyle(pct >= 0 ? Color.iwPrimary : Color.iwTertiary)
                Text("\(pct >= 0 ? "+" : "")\(pct)%")
                    .font(IWFont.labelLarge())
                    .foregroundStyle(pct >= 0 ? Color.iwPrimary : Color.iwTertiary)
            }
        }

        // 7-day dual bar chart
        if !badgesVM.thisWeekDaily.isEmpty {
            let maxSteps = max(
                badgesVM.thisWeekDaily.map(\.steps).max() ?? 1,
                badgesVM.lastWeekDaily.map(\.steps).max() ?? 1,
                1
            )
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<7) { i in
                    VStack(spacing: 2) {
                        ZStack(alignment: .bottom) {
                            // Last week bar (gray, behind)
                            if i < badgesVM.lastWeekDaily.count {
                                let h = CGFloat(badgesVM.lastWeekDaily[i].steps) / CGFloat(maxSteps)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.iwSurfaceContainerHigh)
                                    .frame(height: 50 * h)
                                    .frame(maxWidth: .infinity)
                            }
                            // This week bar (primary, in front)
                            if i < badgesVM.thisWeekDaily.count {
                                let h = CGFloat(badgesVM.thisWeekDaily[i].steps) / CGFloat(maxSteps)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.iwPrimary.opacity(0.85))
                                    .frame(height: 50 * h)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 50)

                        // Day label
                        if i < badgesVM.thisWeekDaily.count {
                            Text(badgesVM.thisWeekDaily[i].shortDayName)
                                .font(IWFont.labelSmall())
                                .foregroundStyle(Color.iwOutline)
                        }
                    }
                }
            }
        }

        Text(badgesVM.comparisonMessage)
            .font(IWFont.bodySmall())
            .foregroundStyle(Color.iwOutline)
    }
}
```

Add this helper inside `BadgesView`:
```swift
private func comparisonStat(label: String, value: String, color: Color) -> some View {
    VStack(alignment: .center, spacing: 2) {
        Text(value)
            .font(IWFont.titleSmall())
            .foregroundStyle(color)
        Text(label)
            .font(IWFont.labelSmall())
            .foregroundStyle(Color.iwOutline)
    }
    .frame(width: 80)
}
```

Also call `loadComparisonData()` in the view's `.task` or `.onAppear`:
```swift
.task {
    await badgesVM.loadComparisonData()
    badgesVM.animateOnAppear()
}
```

- [ ] **Step 4: Build to verify**

```bash
xcodebuild build \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  2>&1 | xcbeautify --quiet
```

Expected: Build Succeeded

- [ ] **Step 5: Commit**

```bash
git add "iWalk AI/Services/HealthKitManager.swift" \
        "iWalk AI/ViewModels/BadgesViewModel.swift" \
        "iWalk AI/Views/BadgesView.swift"
git commit -m "feat: replace fake leaderboard with this-week vs last-week comparison"
```

---

## Verification Checklist

After all tasks complete:

- [ ] Build succeeds without errors or new warnings
- [ ] Walk sessions are saved after completing a walk
- [ ] Walk history page opens from Dashboard, shows session list with expandable details
- [ ] Empty state shows when no walks recorded
- [ ] Coin shop opens from Badges page
- [ ] Spending 20 coins adds a freeze card (balance decreases, freeze card count increases)
- [ ] Cannot purchase when balance is insufficient (button disabled)
- [ ] Theme items show checkmark after purchase
- [ ] Leaderboard card shows this-week vs last-week bars
- [ ] Comparison message reflects actual percentage change
