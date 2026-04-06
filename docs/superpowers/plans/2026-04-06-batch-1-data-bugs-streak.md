# Batch 1: Data Trust + Bug Fixes + Streak Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix data credibility labeling, two core UX bugs, and streak all-day warning + toast deduplication.

**Architecture:** Minimal changes across existing files — no new ViewModels. Toast queue is the only new file. All changes are isolated to their module boundaries.

**Tech Stack:** SwiftUI, @Observable, HealthKit, UserDefaults

---

## File Map

| Action | File |
|--------|------|
| Modify | `iWalk AI/Models/StreakModels.swift` — remove hour guard from `isAtRisk` |
| Modify | `iWalk AI/ViewModels/DashboardViewModel.swift` — add estimated flags, walkDidEnd listener |
| Modify | `iWalk AI/ViewModels/ActiveWalkViewModel.swift` — post walkDidEnd notification |
| Modify | `iWalk AI/ViewModels/CoinViewModel.swift` — integrate ToastQueue |
| Modify | `iWalk AI/ViewModels/StreakViewModel.swift` — integrate ToastQueue |
| Modify | `iWalk AI/Views/DashboardView.swift` — show ~ on estimated values, evening mode animation |
| Create | `iWalk AI/Services/ToastQueue.swift` — serial toast queue |

---

## Task 1: Fix `isAtRisk` — Show Streak Warning All Day

**Files:**
- Modify: `iWalk AI/Models/StreakModels.swift:31-34`

- [ ] **Step 1: Change `isAtRisk` to not require hour >= 20**

In `StreakModels.swift`, replace the `isAtRisk` computed property:

```swift
// BEFORE (line 31-34):
var isAtRisk: Bool {
    let hour = Calendar.current.component(.hour, from: .now)
    return hour >= 20 && !isActiveToday
}

// AFTER:
var isAtRisk: Bool {
    !isActiveToday
}
```

- [ ] **Step 2: Build to verify no errors**

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

- [ ] **Step 3: Commit**

```bash
git add "iWalk AI/Models/StreakModels.swift"
git commit -m "fix: show streak risk warning all day, not just after 20:00"
```

---

## Task 2: Create Toast Queue

**Files:**
- Create: `iWalk AI/Services/ToastQueue.swift`

The current system shows toasts immediately via `DispatchQueue.main.asyncAfter`, causing overlapping toasts when tier rewards + streak rewards fire simultaneously. This task replaces that with a serial queue.

- [ ] **Step 1: Create `ToastQueue.swift`**

```swift
import SwiftUI

struct ToastItem: Identifiable {
    let id = UUID()
    let amount: Int
    let source: CoinSource
}

@Observable
@MainActor
final class ToastQueue {
    static let shared = ToastQueue()

    var current: ToastItem?
    private var queue: [ToastItem] = []
    private var isShowing = false

    private init() {}

    func enqueue(amount: Int, source: CoinSource) {
        let item = ToastItem(amount: amount, source: source)
        queue.append(item)
        if !isShowing {
            showNext()
        }
    }

    private func showNext() {
        guard !queue.isEmpty else {
            isShowing = false
            return
        }
        isShowing = true
        let item = queue.removeFirst()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            current = item
        }
        Task {
            try? await Task.sleep(for: .seconds(2.0))
            withAnimation(.easeOut(duration: 0.3)) {
                self.current = nil
            }
            try? await Task.sleep(for: .seconds(0.35))
            self.showNext()
        }
    }
}
```

- [ ] **Step 2: Update `CoinViewModel.earn()` to use ToastQueue**

In `CoinViewModel.swift`, replace the toast block inside `earn()`:

```swift
// BEFORE (lines 68-75):
lastEarnedAmount = amount
lastEarnedSource = source
withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
    showCoinToast = true
}
DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
    withAnimation(.easeOut(duration: 0.3)) {
        self?.showCoinToast = false
    }
}

// AFTER:
lastEarnedAmount = amount
lastEarnedSource = source
Task { @MainActor in
    ToastQueue.shared.enqueue(amount: amount, source: source)
}
```

Keep `showCoinToast`, `lastEarnedAmount`, `lastEarnedSource` as-is for backward compatibility — they're used by `CoinToast` display logic.

- [ ] **Step 3: Update `CoinToast` display in root view to use ToastQueue**

In `iWalk AI/Views/MainTabView.swift` (or wherever `CoinToast` is shown), find the overlay and update it to read from `ToastQueue.shared.current`:

Open `MainTabView.swift` to check current structure first, then update the overlay:

```swift
// Replace any existing CoinToast overlay with:
.overlay(alignment: .top) {
    if let toast = ToastQueue.shared.current {
        CoinToast(amount: toast.amount, source: toast.source)
            .padding(.top, 60)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
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
git add "iWalk AI/Services/ToastQueue.swift" \
        "iWalk AI/ViewModels/CoinViewModel.swift" \
        "iWalk AI/Views/MainTabView.swift"
git commit -m "feat: serial toast queue to prevent overlapping coin notifications"
```

---

## Task 3: Data Source Labeling (~ for estimated values)

**Files:**
- Modify: `iWalk AI/ViewModels/DashboardViewModel.swift`
- Modify: `iWalk AI/Views/DashboardView.swift`

- [ ] **Step 1: Add estimated flags to `DashboardViewModel`**

After line 8 (`var hasLoadedRealData = false`), add:

```swift
var isDistanceEstimated = true
var isCaloriesEstimated = true
```

- [ ] **Step 2: Set flags in `refreshFromHealthKit()`**

In `refreshFromHealthKit()`, replace the stats block (lines 78-90) with:

```swift
await MainActor.run {
    todayStats.steps = steps
    if distance > 0 {
        todayStats.distanceKm = distance
        isDistanceEstimated = false
    } else {
        todayStats.distanceKm = Double(steps) / 1400.0
        isDistanceEstimated = true
    }
    if calories > 0 {
        todayStats.calories = calories
        isCaloriesEstimated = false
    } else {
        todayStats.calories = steps / 20
        isCaloriesEstimated = true
    }
    todayStats.activeMinutes = steps / 200

    withAnimation(.easeOut(duration: 0.3)) {
        animatedSteps = todayStats.steps
        animatedProgress = targetProgress
    }

    coinVM.checkStepTiers(currentSteps: steps)
    if steps >= 1500 {
        streakVM.completeTodayIfNeeded(coinVM: coinVM)
    }
}
```

- [ ] **Step 3: Same fix in `loadRealData()`**

In `loadRealData()`, replace the stats block (lines 120-127):

```swift
await MainActor.run {
    hasLoadedRealData = true
    todayStats.steps = steps
    if distance > 0 {
        todayStats.distanceKm = distance
        isDistanceEstimated = false
    } else {
        todayStats.distanceKm = Double(steps) / 1400.0
        isDistanceEstimated = true
    }
    if calories > 0 {
        todayStats.calories = calories
        isCaloriesEstimated = false
    } else {
        todayStats.calories = steps / 20
        isCaloriesEstimated = true
    }
    todayStats.activeMinutes = steps / 200
    if !weekly.isEmpty {
        weeklyActivity = weekly
    }
    animatedSteps = todayStats.steps
    withAnimation(.easeOut(duration: 0.6)) {
        animatedProgress = targetProgress
    }
}
```

- [ ] **Step 4: Show "~" prefix in DashboardView stat cards**

Open `DashboardView.swift` and find the `StatCard` calls for distance and calories. Add `~` prefix when estimated. The pattern will look like:

```swift
// For distance StatCard, change the value parameter:
StatCard(
    icon: "figure.walk",
    value: "\(vm.isDistanceEstimated ? "~" : "")\(String(format: "%.1f", vm.todayStats.distanceKm))",
    label: "km"
)

// For calories StatCard:
StatCard(
    icon: "flame",
    value: "\(vm.isCaloriesEstimated ? "~" : "")\(vm.todayStats.calories)",
    label: "kcal"
)
```

Read the exact StatCard call sites in DashboardView first to match the exact parameter names and format.

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
git add "iWalk AI/ViewModels/DashboardViewModel.swift" \
        "iWalk AI/Views/DashboardView.swift"
git commit -m "feat: label estimated distance and calorie values with ~ prefix"
```

---

## Task 4: Immediate Refresh After Walk Ends

**Files:**
- Modify: `iWalk AI/ViewModels/ActiveWalkViewModel.swift`
- Modify: `iWalk AI/ViewModels/DashboardViewModel.swift`

- [ ] **Step 1: Post notification in `ActiveWalkViewModel.endWalk()`**

In `ActiveWalkViewModel.swift`, add at the top after `import SwiftUI`:

```swift
extension Notification.Name {
    static let walkDidEnd = Notification.Name("iw_walkDidEnd")
}
```

In `endWalk()`, add after `invalidateAll()`:

```swift
func endWalk() {
    invalidateAll()
    NotificationCenter.default.post(name: .walkDidEnd, object: nil)
    let session = WalkSession(
        // ... existing code unchanged
    )
    withAnimation(.easeInOut(duration: 0.4)) {
        phase = .summary(session)
    }
}
```

- [ ] **Step 2: Listen in `DashboardViewModel`**

Add a stored property for the notification observer after `private var refreshTimer: Timer?`:

```swift
private var walkEndObserver: NSObjectProtocol?
```

Add a new method `setupNotifications(coinVM:streakVM:)`:

```swift
func setupNotifications(coinVM: CoinViewModel, streakVM: StreakViewModel) {
    walkEndObserver = NotificationCenter.default.addObserver(
        forName: .walkDidEnd,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.refreshFromHealthKit(coinVM: coinVM, streakVM: streakVM)
    }
}
```

Add cleanup in `stopAutoRefresh()`:

```swift
func stopAutoRefresh() {
    refreshTimer?.invalidate()
    refreshTimer = nil
    if let obs = walkEndObserver {
        NotificationCenter.default.removeObserver(obs)
        walkEndObserver = nil
    }
}
```

- [ ] **Step 3: Call `setupNotifications` from the view**

In `DashboardView.swift`, find where `vm.startAutoRefresh(coinVM:streakVM:)` is called (likely in `.onAppear`) and add:

```swift
vm.setupNotifications(coinVM: coinVM, streakVM: streakVM)
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
git add "iWalk AI/ViewModels/ActiveWalkViewModel.swift" \
        "iWalk AI/ViewModels/DashboardViewModel.swift" \
        "iWalk AI/Views/DashboardView.swift"
git commit -m "fix: refresh HealthKit data immediately when walk session ends"
```

---

## Task 5: Evening Mode Crossfade Animation

**Files:**
- Modify: `iWalk AI/Views/DashboardView.swift`

- [ ] **Step 1: Find the evening/day mode conditional in DashboardView**

The structure is an `if vm.isEveningMode { ... } else { ... }` block. Wrap it with `.animation` value binding:

```swift
// Wrap the if/else block like this:
Group {
    if vm.isEveningMode {
        EveningReviewCard(/* existing params */)
            .transition(.opacity)
    } else {
        // existing day content
        TieredProgressBar(/* existing params */)
            .transition(.opacity)
    }
}
.animation(.easeInOut(duration: 0.4), value: vm.isEveningMode)
```

Read the actual content of the if/else block in DashboardView first to wrap it correctly.

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  2>&1 | xcbeautify --quiet
```

Expected: Build Succeeded

- [ ] **Step 3: Commit**

```bash
git add "iWalk AI/Views/DashboardView.swift"
git commit -m "fix: crossfade animation when switching between day and evening mode"
```

---

## Task 6: Reward Deduplication

**Files:**
- Modify: `iWalk AI/ViewModels/CoinViewModel.swift`

The risk: `checkStepTiers()` fires tier rewards, and `StreakViewModel.completeTodayIfNeeded()` fires streak rewards in the same `refreshFromHealthKit()` call. They don't overlap in source (stepTier vs streak) so they're already distinct. The real issue is `personalGoal` reward can fire alongside a tier reward. Add a session-level dedup key for `personalGoal` to match tiers' `isReached` pattern (already implemented for tiers).

- [ ] **Step 1: Verify `personalGoal.isReached` persists correctly**

In `CoinViewModel.checkStepTiers()`, `personalGoal.isReached` is set to `true` but `personalGoal` is only saved via `saveTiers()` — not `savePersonalGoal()`. Fix this by calling `savePersonalGoal()` after setting `personalGoal.isReached`:

```swift
if !personalGoal.isReached && currentSteps >= personalGoal.targetSteps {
    personalGoal.isReached = true
    earn(
        amount: personalGoal.coinReward,
        source: .personalGoal,
        description: "Personal goal: \(personalGoal.targetSteps.formatted()) steps"
    )
    savePersonalGoal()  // Add this line
}
```

- [ ] **Step 2: Build and commit**

```bash
xcodebuild build \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  2>&1 | xcbeautify --quiet
```

```bash
git add "iWalk AI/ViewModels/CoinViewModel.swift"
git commit -m "fix: persist personal goal isReached to prevent duplicate coin rewards"
```

---

## Verification Checklist

After all tasks complete:

- [ ] Build succeeds without errors or new warnings
- [ ] Streak warning shows at any time of day (not just 20:00+)
- [ ] Multiple simultaneous coin rewards queue and show sequentially
- [ ] Distance shows "~" prefix when HealthKit distance is unavailable
- [ ] Calories shows "~" prefix when HealthKit calories is unavailable
- [ ] Walking and ending a session triggers immediate step count refresh on Dashboard
- [ ] Evening mode switches with a smooth fade (not instant)
- [ ] Personal goal reward only fires once per day
