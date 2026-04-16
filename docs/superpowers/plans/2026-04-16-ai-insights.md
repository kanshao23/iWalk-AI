# AI Insights Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the rule-based AI insight text in TieredProgressBar and enrich the AI Coach API context with real walk history analysis, creating a personalized "aha moment" by Day 4-7.

**Architecture:** New `WalkInsightsEngine` (pure static functions, no async) analyzes `[WalkSession]` history from UserDefaults. Results flow in two directions: (1) `insightText` replaces the rule-based string in `TieredProgressBar`'s bottom card; (2) structured fields are injected into `CoachAPIClient.CoachContext` so the backend Claude model produces genuinely personalized replies.

**Tech Stack:** Swift 5.0, SwiftUI, XCTest, no new dependencies.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `iWalk AI/Services/WalkInsightsEngine.swift` | CREATE | Pure analytics: pace trend, time-of-day, week comparison, insight text |
| `iWalk AI Tests/WalkInsightsEngineTests.swift` | CREATE | Unit tests for all engine logic |
| `iWalk AI/Views/Components/TieredProgressBar.swift` | MODIFY | Accept optional `WalkInsightSummary`; use its text when available |
| `iWalk AI/ViewModels/DashboardViewModel.swift` | MODIFY | Compute + store `walkInsights` after data load and after walk ends |
| `iWalk AI/Views/DashboardView.swift` | MODIFY | Pass `vm.walkInsights` to `TieredProgressBar` |
| `iWalk AI/Services/CoachAPIClient.swift` | MODIFY | Add 6 new fields to `CoachContext` |
| `iWalk AI/ViewModels/CoachViewModel.swift` | MODIFY | Run engine in `refreshContext()`; use enriched context in chat |

---

## Task 1: Data Models

**Files:**
- Create: `iWalk AI/Services/WalkInsightsEngine.swift`
- Create: `iWalk AI Tests/WalkInsightsEngineTests.swift`

- [ ] **Step 1: Create WalkInsightsEngine.swift with models only**

```swift
// iWalk AI/Services/WalkInsightsEngine.swift
import Foundation

enum PaceTrend: String {
    case improving, stable, declining
}

enum TimeOfDay: String {
    case morning, afternoon, evening, unknown
}

struct WeekComparison {
    let thisWeekWalks: Int
    let lastWeekWalks: Int
    let thisWeekSteps: Int
    let lastWeekSteps: Int
}

struct WalkInsightSummary {
    /// Ready-to-display string. nil when history < 3 walks (caller uses fallback).
    let insightText: String?
    let paceTrend: PaceTrend
    let bestTimeOfDay: TimeOfDay
    let weekComparison: WeekComparison
    let totalWalks: Int
    let avgPaceMinPerKm: Double
}

struct WalkInsightsEngine {
    // Implementation added in later tasks
}
```

- [ ] **Step 2: Create test file with a helper factory**

```swift
// iWalk AI Tests/WalkInsightsEngineTests.swift
import XCTest
@testable import iWalk_AI

final class WalkInsightsEngineTests: XCTestCase {

    // MARK: - Helper

    /// Creates a WalkSession with controlled start time and pace.
    /// - Parameters:
    ///   - startHour: Hour of day (0–23). Default 8 (morning).
    ///   - daysAgo: How many days before today the walk started. Default 0.
    ///   - distanceKm: Route distance. Default 3.0 km.
    ///   - elapsedSeconds: Duration. Default 1500 s (25 min) → pace ≈ 8.33 min/km.
    private func makeSession(
        startHour: Int = 8,
        daysAgo: Int = 0,
        distanceKm: Double = 3.0,
        elapsedSeconds: Int = 1500
    ) -> WalkSession {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.day! -= daysAgo
        comps.hour = startHour
        comps.minute = 0
        let start = Calendar.current.date(from: comps)!
        return WalkSession(
            startTime: start,
            endTime: start.addingTimeInterval(Double(elapsedSeconds)),
            steps: Int(distanceKm * 1350),
            calories: Int(distanceKm * 1350) / 20,
            distanceKm: distanceKm,
            elapsedSeconds: elapsedSeconds,
            dailyGoal: 10_000,
            stepsBeforeWalk: 2_000,
            averageHeartRate: 75,
            routePoints: nil
        )
    }
}
```

- [ ] **Step 3: Build to confirm models compile**

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export PATH="$DEVELOPER_DIR/usr/bin:$PATH"
xcodebuild build \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  2>&1 | xcbeautify --quiet --disable-colored-output
```

Expected: `Build Succeeded`

---

## Task 2: Pace Trend

**Files:**
- Modify: `iWalk AI/Services/WalkInsightsEngine.swift`
- Modify: `iWalk AI Tests/WalkInsightsEngineTests.swift`

- [ ] **Step 1: Write failing tests**

Add inside `WalkInsightsEngineTests`:

```swift
// MARK: - paceTrend

func test_paceTrend_improving_whenRecentFasterByMoreThan5Pct() {
    // Recent 3: elapsedSeconds=1200 → pace = 20/3 = 6.67 min/km
    // Previous 3: elapsedSeconds=1500 → pace = 25/3 = 8.33 min/km
    // Change = (6.67 - 8.33) / 8.33 = -0.20 → improving
    let recent = (0..<3).map { makeSession(daysAgo: $0, elapsedSeconds: 1200) }
    let previous = (3..<6).map { makeSession(daysAgo: $0, elapsedSeconds: 1500) }
    let history = recent + previous
    XCTAssertEqual(WalkInsightsEngine.paceTrend(from: history), .improving)
}

func test_paceTrend_declining_whenRecentSlowerByMoreThan5Pct() {
    // Recent 3: elapsedSeconds=1800 → pace = 30/3 = 10.0 min/km
    // Previous 3: elapsedSeconds=1500 → pace = 25/3 = 8.33 min/km
    // Change = (10.0 - 8.33) / 8.33 = +0.20 → declining
    let recent = (0..<3).map { makeSession(daysAgo: $0, elapsedSeconds: 1800) }
    let previous = (3..<6).map { makeSession(daysAgo: $0, elapsedSeconds: 1500) }
    let history = recent + previous
    XCTAssertEqual(WalkInsightsEngine.paceTrend(from: history), .declining)
}

func test_paceTrend_stable_whenDifferenceLessThan5Pct() {
    // Recent 3: elapsedSeconds=1530 → pace = 8.50 min/km
    // Previous 3: elapsedSeconds=1500 → pace = 8.33 min/km
    // Change = (8.50 - 8.33) / 8.33 = +0.02 → stable
    let recent = (0..<3).map { makeSession(daysAgo: $0, elapsedSeconds: 1530) }
    let previous = (3..<6).map { makeSession(daysAgo: $0, elapsedSeconds: 1500) }
    let history = recent + previous
    XCTAssertEqual(WalkInsightsEngine.paceTrend(from: history), .stable)
}

func test_paceTrend_stable_whenFewerThan6WalksWithPace() {
    let history = (0..<5).map { makeSession(daysAgo: $0) }
    XCTAssertEqual(WalkInsightsEngine.paceTrend(from: history), .stable)
}
```

- [ ] **Step 2: Implement `paceTrend(from:)`**

Add inside `WalkInsightsEngine` struct:

```swift
/// Compares average pace of the 3 most recent walks vs the 3 before them.
/// Requires ≥6 walks with distance > 0.01 km; returns .stable otherwise.
static func paceTrend(from history: [WalkSession]) -> PaceTrend {
    let withPace = history.filter { $0.paceMinPerKm > 0 }
    guard withPace.count >= 6 else { return .stable }

    let recentPaces = withPace.prefix(3).map(\.paceMinPerKm)
    let previousPaces = withPace.dropFirst(3).prefix(3).map(\.paceMinPerKm)

    let recentAvg = recentPaces.reduce(0, +) / Double(recentPaces.count)
    let prevAvg = previousPaces.reduce(0, +) / Double(previousPaces.count)
    guard prevAvg > 0 else { return .stable }

    let change = (recentAvg - prevAvg) / prevAvg
    // Lower min/km = faster
    if change < -0.05 { return .improving }
    if change >  0.05 { return .declining }
    return .stable
}
```

- [ ] **Step 3: Run tests**

```bash
killall Simulator 2>/dev/null; sleep 2
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export PATH="$DEVELOPER_DIR/usr/bin:$PATH"
xcodebuild test \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -only-testing:"iWalk AI Tests/WalkInsightsEngineTests" \
  2>&1 | xcbeautify --quiet --disable-colored-output
```

Expected: all 4 pace trend tests pass.

---

## Task 3: Best Time of Day

**Files:**
- Modify: `iWalk AI/Services/WalkInsightsEngine.swift`
- Modify: `iWalk AI Tests/WalkInsightsEngineTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// MARK: - bestTimeOfDay

func test_bestTimeOfDay_morning_when4MorningAnd1Afternoon() {
    // 4 morning walks (hour=8), 1 afternoon (hour=14) → morning wins with ≥3
    let history = (0..<4).map { makeSession(startHour: 8, daysAgo: $0) }
              + [makeSession(startHour: 14, daysAgo: 4)]
    XCTAssertEqual(WalkInsightsEngine.bestTimeOfDay(from: history), .morning)
}

func test_bestTimeOfDay_unknown_whenNoBracketHas3OrMore() {
    // 2 morning, 2 afternoon, 1 evening — no bracket has ≥3
    let history = (0..<2).map { makeSession(startHour: 8,  daysAgo: $0) }
              + (2..<4).map { makeSession(startHour: 14, daysAgo: $0) }
              + [makeSession(startHour: 20, daysAgo: 4)]
    XCTAssertEqual(WalkInsightsEngine.bestTimeOfDay(from: history), .unknown)
}

func test_bestTimeOfDay_unknown_whenFewerThan3Walks() {
    let history = (0..<2).map { makeSession(startHour: 8, daysAgo: $0) }
    XCTAssertEqual(WalkInsightsEngine.bestTimeOfDay(from: history), .unknown)
}

func test_bestTimeOfDay_evening_when3EveningWalks() {
    let history = (0..<3).map { makeSession(startHour: 20, daysAgo: $0) }
    XCTAssertEqual(WalkInsightsEngine.bestTimeOfDay(from: history), .evening)
}
```

- [ ] **Step 2: Implement `bestTimeOfDay(from:)`**

```swift
/// Returns the time bracket (morning/afternoon/evening) with ≥3 walks.
/// Returns .unknown if no bracket qualifies or history < 3.
static func bestTimeOfDay(from history: [WalkSession]) -> TimeOfDay {
    guard history.count >= 3 else { return .unknown }

    var counts: [TimeOfDay: Int] = [.morning: 0, .afternoon: 0, .evening: 0]
    let cal = Calendar.current
    for session in history {
        let hour = cal.component(.hour, from: session.startTime)
        switch hour {
        case 5..<12: counts[.morning,   default: 0] += 1
        case 12..<18: counts[.afternoon, default: 0] += 1
        case 18..<24: counts[.evening,   default: 0] += 1
        default: break
        }
    }

    guard let winner = counts.max(by: { $0.value < $1.value }),
          winner.value >= 3 else { return .unknown }
    return winner.key
}
```

- [ ] **Step 3: Run tests**

```bash
xcodebuild test \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -only-testing:"iWalk AI Tests/WalkInsightsEngineTests" \
  2>&1 | xcbeautify --quiet --disable-colored-output
```

Expected: all 8 tests (4 pace + 4 time-of-day) pass.

---

## Task 4: Week Comparison

**Files:**
- Modify: `iWalk AI/Services/WalkInsightsEngine.swift`
- Modify: `iWalk AI Tests/WalkInsightsEngineTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// MARK: - weekComparison

func test_weekComparison_countsThisWeekCorrectly() {
    // 2 walks today + 1 walk 8 days ago (last week)
    let thisWeek = (0..<2).map { makeSession(daysAgo: $0) }
    let lastWeek = [makeSession(daysAgo: 8)]
    let result = WalkInsightsEngine.weekComparison(from: thisWeek + lastWeek)
    XCTAssertEqual(result.thisWeekWalks, 2)
    XCTAssertEqual(result.lastWeekWalks, 1)
}

func test_weekComparison_stepsAccumulate() {
    // 2 walks this week, each 3.0 km → 4050 steps each (Int(3.0 * 1350))
    let history = (0..<2).map { makeSession(daysAgo: $0, distanceKm: 3.0) }
    let result = WalkInsightsEngine.weekComparison(from: history)
    XCTAssertEqual(result.thisWeekSteps, 4050 * 2)
    XCTAssertEqual(result.lastWeekSteps, 0)
}

func test_weekComparison_emptyHistoryReturnsZeros() {
    let result = WalkInsightsEngine.weekComparison(from: [])
    XCTAssertEqual(result.thisWeekWalks, 0)
    XCTAssertEqual(result.lastWeekWalks, 0)
}
```

- [ ] **Step 2: Implement `weekComparison(from:)`**

```swift
/// Groups sessions into the current and previous calendar week.
static func weekComparison(from history: [WalkSession]) -> WeekComparison {
    let cal = Calendar.current
    let now = Date()
    guard let thisWeekInterval = cal.dateInterval(of: .weekOfYear, for: now) else {
        return WeekComparison(thisWeekWalks: 0, lastWeekWalks: 0,
                              thisWeekSteps: 0, lastWeekSteps: 0)
    }
    let lastWeekStart = cal.date(byAdding: .weekOfYear, value: -1,
                                  to: thisWeekInterval.start)!

    let thisWeek = history.filter { thisWeekInterval.contains($0.startTime) }
    let lastWeek = history.filter {
        $0.startTime >= lastWeekStart && $0.startTime < thisWeekInterval.start
    }

    return WeekComparison(
        thisWeekWalks: thisWeek.count,
        lastWeekWalks: lastWeek.count,
        thisWeekSteps: thisWeek.map(\.steps).reduce(0, +),
        lastWeekSteps: lastWeek.map(\.steps).reduce(0, +)
    )
}
```

- [ ] **Step 3: Run tests**

```bash
xcodebuild test \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -only-testing:"iWalk AI Tests/WalkInsightsEngineTests" \
  2>&1 | xcbeautify --quiet --disable-colored-output
```

Expected: all 11 tests pass.

---

## Task 5: Insight Text + `analyze()` + Commit Engine

**Files:**
- Modify: `iWalk AI/Services/WalkInsightsEngine.swift`
- Modify: `iWalk AI Tests/WalkInsightsEngineTests.swift`

- [ ] **Step 1: Write failing tests for insightText**

```swift
// MARK: - insightText

func test_insightText_nilWhenFewerThan3Walks() {
    let history = (0..<2).map { makeSession(daysAgo: $0) }
    let summary = WalkInsightsEngine.analyze(history: history)
    XCTAssertNil(summary.insightText)
}

func test_insightText_consistencyTier_with3to6Walks() {
    let history = (0..<4).map { makeSession(daysAgo: $0) }
    let summary = WalkInsightsEngine.analyze(history: history)
    XCTAssertNotNil(summary.insightText)
    // Should mention walks and pace
    XCTAssertTrue(summary.insightText!.contains("walk"))
    XCTAssertTrue(summary.insightText!.contains("min/km"))
}

func test_insightText_patternTier_with7PlusWalksAndKnownTimeOfDay() {
    // 7 morning walks → bestTimeOfDay = .morning → pattern insight
    let history = (0..<7).map { makeSession(startHour: 8, daysAgo: $0) }
    let summary = WalkInsightsEngine.analyze(history: history)
    XCTAssertNotNil(summary.insightText)
    XCTAssertTrue(summary.insightText!.lowercased().contains("morning"))
}

func test_insightText_fallsBackToConsistency_with7WalksButUnknownTimeOfDay() {
    // 2 morning, 2 afternoon, 3 evening (evening wins with exactly 3) → evening
    let history = (0..<2).map { makeSession(startHour: 8,  daysAgo: $0) }
              + (2..<4).map { makeSession(startHour: 14, daysAgo: $0) }
              + (4..<7).map { makeSession(startHour: 20, daysAgo: $0) }
    let summary = WalkInsightsEngine.analyze(history: history)
    XCTAssertNotNil(summary.insightText)
    XCTAssertTrue(summary.insightText!.lowercased().contains("evening"))
}
```

- [ ] **Step 2: Implement private helpers + `insightText` + `analyze()`**

Add to `WalkInsightsEngine`:

```swift
/// Formats a pace value in min/km to "M:SS" string.
private static func formatPace(_ paceMinPerKm: Double) -> String {
    guard paceMinPerKm > 0, paceMinPerKm < 100 else { return "--:--" }
    let mins = Int(paceMinPerKm)
    let secs = Int((paceMinPerKm - Double(mins)) * 60)
    return String(format: "%d:%02d", mins, secs)
}

/// Average pace of up to the 5 most recent walks that have valid distance.
private static func averagePace(from history: [WalkSession]) -> Double {
    let valid = history.filter { $0.paceMinPerKm > 0 }.prefix(5)
    guard !valid.isEmpty else { return 0 }
    return valid.map(\.paceMinPerKm).reduce(0, +) / Double(valid.count)
}

/// Returns nil when history < 3 walks (caller should use its own fallback text).
private static func insightText(
    history: [WalkSession],
    paceTrend: PaceTrend,
    bestTimeOfDay: TimeOfDay,
    weekComparison: WeekComparison
) -> String? {
    guard history.count >= 3 else { return nil }

    // 7+ walks AND known time of day → personal pattern
    if history.count >= 7 {
        let trendSuffix = paceTrend == .improving ? " — pace improving" : ""
        switch bestTimeOfDay {
        case .morning:
            return "You walk best in the morning\(trendSuffix). \(weekComparison.thisWeekWalks) walks this week."
        case .afternoon:
            return "Afternoon is your sweet spot\(trendSuffix). \(weekComparison.thisWeekWalks) walks this week."
        case .evening:
            return "Evening walks are your habit\(trendSuffix). \(weekComparison.thisWeekWalks) walks this week."
        case .unknown:
            break
        }
    }

    // 3–6 walks OR unknown pattern → consistency + pace
    let avgPace = averagePace(from: history)
    let paceStr = formatPace(avgPace)
    let count = weekComparison.thisWeekWalks
    let word = count == 1 ? "walk" : "walks"
    return "\(count) \(word) this week · avg pace \(paceStr) min/km"
}

/// Main entry point. Always returns a summary; `insightText` is nil when < 3 walks.
static func analyze(history: [WalkSession]) -> WalkInsightSummary {
    let trend = paceTrend(from: history)
    let tod   = bestTimeOfDay(from: history)
    let week  = weekComparison(from: history)
    let text  = insightText(history: history, paceTrend: trend,
                            bestTimeOfDay: tod, weekComparison: week)
    let avg   = averagePace(from: history)

    return WalkInsightSummary(
        insightText: text,
        paceTrend: trend,
        bestTimeOfDay: tod,
        weekComparison: week,
        totalWalks: history.count,
        avgPaceMinPerKm: avg
    )
}
```

- [ ] **Step 3: Run all engine tests**

```bash
xcodebuild test \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -only-testing:"iWalk AI Tests/WalkInsightsEngineTests" \
  2>&1 | xcbeautify --quiet --disable-colored-output
```

Expected: all 15 tests pass.

- [ ] **Step 4: Commit engine**

```bash
git add "iWalk AI/Services/WalkInsightsEngine.swift" \
        "iWalk AI Tests/WalkInsightsEngineTests.swift"
git commit -m "feat: add WalkInsightsEngine with pace trend, time-of-day, and insight text"
```

---

## Task 6: Wire Up Dashboard + TieredProgressBar

**Files:**
- Modify: `iWalk AI/Views/Components/TieredProgressBar.swift`
- Modify: `iWalk AI/ViewModels/DashboardViewModel.swift`
- Modify: `iWalk AI/Views/DashboardView.swift`

- [ ] **Step 1: Add `insights` param to TieredProgressBar**

In `TieredProgressBar.swift`, add after `var animatedProgress: Double?`:

```swift
var insights: WalkInsightSummary? = nil
```

Then replace the `aiInsight` computed property:

```swift
private var aiInsight: String {
    // Use history-based insight when available (≥3 walks)
    if let text = insights?.insightText { return text }

    // Fallback: rule-based text based on today's progress
    let remaining = goalSteps - currentSteps
    let goalProgress = Double(currentSteps) / Double(goalSteps)

    if goalProgress >= 1.0 {
        return "Goal crushed! Keep going to earn bonus tier coins."
    } else if goalProgress >= 0.75 {
        return "Almost there! Just \(remaining.formatted()) steps to your daily goal."
    } else if isAheadOfSchedule {
        return "Great pace! You're ahead of schedule — \(Int(goalProgress * 100))% done."
    } else if goalProgress >= 0.5 {
        return "Halfway there! A 15-min walk will get you back on track."
    } else if goalProgress >= 0.25 {
        return "Good start! Try a walk after lunch to boost your progress."
    } else {
        return "Let's get moving! A short walk can lift your energy and mood."
    }
}
```

- [ ] **Step 2: Add `walkInsights` to DashboardViewModel**

In `DashboardViewModel.swift`, add after `var eveningReview: EveningReview?`:

```swift
var walkInsights: WalkInsightSummary?
```

At the end of `loadRealData()`, before the closing brace of `await MainActor.run { ... }`, add:

```swift
walkInsights = WalkInsightsEngine.analyze(history: ActiveWalkViewModel.loadHistory())
```

In `onWalkCompleted(session:)`, after `showActiveWalk = false`, add:

```swift
walkInsights = WalkInsightsEngine.analyze(history: ActiveWalkViewModel.loadHistory())
```

- [ ] **Step 3: Pass insights in DashboardView**

In `DashboardView.swift`, update the `TieredProgressBar` call:

```swift
TieredProgressBar(
    currentSteps: vm.animatedSteps,
    goalSteps: vm.stepGoal,
    tiers: coinVM.todayTiers,
    personalGoal: coinVM.personalGoal,
    animatedProgress: vm.animatedProgress,
    insights: vm.walkInsights
)
```

- [ ] **Step 4: Build**

```bash
xcodebuild build \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  2>&1 | xcbeautify --quiet --disable-colored-output
```

Expected: `Build Succeeded`

- [ ] **Step 5: Commit**

```bash
git add "iWalk AI/Views/Components/TieredProgressBar.swift" \
        "iWalk AI/ViewModels/DashboardViewModel.swift" \
        "iWalk AI/Views/DashboardView.swift"
git commit -m "feat: show personalized walk insights in dashboard progress bar"
```

---

## Task 7: Enrich Coach API Context

**Files:**
- Modify: `iWalk AI/Services/CoachAPIClient.swift`
- Modify: `iWalk AI/ViewModels/CoachViewModel.swift`

- [ ] **Step 1: Add fields to CoachContext**

In `CoachAPIClient.swift`, replace `struct CoachContext`:

```swift
struct CoachContext: Encodable {
    // Existing
    let steps: Int
    let streak: Int
    let goal: Int
    let userName: String
    // Walk history summary (defaults to zero/unknown for new users)
    let totalWalks: Int
    let avgPaceMinPerKm: Double
    let bestTimeOfDay: String   // "morning" | "afternoon" | "evening" | "unknown"
    let paceTrend: String       // "improving" | "stable" | "declining"
    let thisWeekWalks: Int
    let lastWeekWalks: Int
}
```

- [ ] **Step 2: Store insights in CoachViewModel**

In `CoachViewModel.swift`, add private property after `private var pendingResponseCount`:

```swift
private var walkInsights: WalkInsightSummary?
```

At the end of `refreshContext(streak:)`, after setting `hasRealActivityData`, add:

```swift
walkInsights = WalkInsightsEngine.analyze(history: ActiveWalkViewModel.loadHistory())
```

- [ ] **Step 3: Use enriched context when sending messages**

In `CoachViewModel.swift`, replace the `let context = CoachAPIClient.CoachContext(...)` block inside `enqueueAssistantResponse(for:)`:

```swift
let insights = walkInsights
let context = CoachAPIClient.CoachContext(
    steps: todaySteps,
    streak: streak.currentStreak,
    goal: goalSteps,
    userName: user.name,
    totalWalks: insights?.totalWalks ?? 0,
    avgPaceMinPerKm: insights?.avgPaceMinPerKm ?? 0.0,
    bestTimeOfDay: insights?.bestTimeOfDay.rawValue ?? "unknown",
    paceTrend: insights?.paceTrend.rawValue ?? "stable",
    thisWeekWalks: insights?.weekComparison.thisWeekWalks ?? 0,
    lastWeekWalks: insights?.weekComparison.lastWeekWalks ?? 0
)
```

- [ ] **Step 4: Build**

```bash
xcodebuild build \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  2>&1 | xcbeautify --quiet --disable-colored-output
```

Expected: `Build Succeeded`

- [ ] **Step 5: Commit and push**

```bash
git add "iWalk AI/Services/CoachAPIClient.swift" \
        "iWalk AI/ViewModels/CoachViewModel.swift"
git commit -m "feat: enrich AI Coach context with walk history (pace, time-of-day, trends)"
git push
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] WalkInsightsEngine with pace trend, time-of-day, week comparison → Tasks 2-5
- [x] insightText 3-tier logic (0-2 / 3-6 / 7+) → Task 5
- [x] TieredProgressBar uses insightText when available → Task 6
- [x] DashboardViewModel computes insights after load and after walk → Task 6
- [x] CoachContext enriched with 6 new fields → Task 7
- [x] CoachViewModel populates fields from engine → Task 7
- [x] Fallback behavior when no history → nil insightText, zero context fields

**Type consistency:**
- `WalkInsightSummary.insightText` is `String?` throughout (nil = use fallback) ✓
- `PaceTrend.rawValue` and `TimeOfDay.rawValue` used in Task 7 match enums defined in Task 1 ✓
- `WalkInsightsEngine.analyze(history:)` signature used consistently in Tasks 5, 6, 7 ✓
- `ActiveWalkViewModel.loadHistory()` is a static method — used correctly in Tasks 6 and 7 ✓
