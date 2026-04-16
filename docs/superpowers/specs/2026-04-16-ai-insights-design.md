# AI Insights Feature Design
Date: 2026-04-16

## Product Goal

Create the "aha moment" that justifies the subscription paywall: within 7 days of first use,
the user sees insights that feel personal — derived from their own walk history, not generic
health tips. Target conversion window: Day 4-7 after trial start.

## Architecture: Option C — Local Engine + Enriched Coach Context

Two existing surfaces receive real data without adding new UI sections:
1. The `aiInsight` text at the bottom of `TieredProgressBar` (Dashboard hero card)
2. The AI Coach API context (makes chat responses genuinely personalized)

## Data Layer

### WalkInsightsEngine (new file)

Pure computation service. No async, no network. Reads `[WalkSession]` from
`ActiveWalkViewModel.loadHistory()` and returns a `WalkInsightSummary`.

**Output model:**
```swift
struct WalkInsightSummary {
    let insightText: String           // ready-to-display string for TieredProgressBar
    let paceTrend: PaceTrend          // .improving / .stable / .declining
    let bestTimeOfDay: TimeOfDay      // .morning / .afternoon / .evening / .unknown
    let weekComparison: WeekComparison
    let totalWalks: Int
}

struct WeekComparison {
    let thisWeekWalks: Int
    let lastWeekWalks: Int
    let thisWeekSteps: Int
    let lastWeekSteps: Int
}

enum PaceTrend { case improving, stable, declining }
enum TimeOfDay { case morning, afternoon, evening, unknown }
```

**Three data tiers for insightText:**

| Walk count | Insight type | Example |
|---|---|---|
| 0–2 | Fallback (existing rules) | "Great pace! You're ahead of schedule." |
| 3–6 | Consistency + pace | "3 walks this week · avg pace 8:20 min/km" |
| 7+ | Personal pattern | "Your morning pace is 12% faster — you're a morning walker" |

**Pace trend calculation:** Compare average pace of last 3 walks vs previous 3 walks.
Threshold: >5% improvement = improving, >5% slower = declining, else stable.

**Best time of day:** Group walk `startTime` by hour bracket:
- Morning: 05:00–11:59
- Afternoon: 12:00–17:59
- Evening: 18:00–23:59
Winner = bracket with most walks. Requires ≥3 walks in a bracket to declare a winner.

## UI Changes

### TieredProgressBar

Add optional parameter `insights: WalkInsightSummary?`. The `aiInsight` computed property
uses `insights.insightText` when available, falls back to existing rule-based logic otherwise.
No visual changes — same single-line text area.

```swift
// Before
TieredProgressBar(currentSteps:, goalSteps:, tiers:, personalGoal:, animatedProgress:)

// After
TieredProgressBar(currentSteps:, goalSteps:, tiers:, personalGoal:, animatedProgress:, insights:)
```

### DashboardViewModel

- New property: `var walkInsights: WalkInsightSummary?`
- Compute insights synchronously at the end of `loadRealData()` using
  `WalkInsightsEngine.analyze(history: ActiveWalkViewModel.loadHistory())`
- Also recompute in `onWalkCompleted()` so the insight updates immediately after a walk ends

## Coach Context Enrichment

### CoachAPIClient.CoachContext — new fields

```swift
struct CoachContext: Encodable {
    // Existing
    let steps: Int
    let streak: Int
    let goal: Int
    let userName: String
    // New
    let totalWalks: Int
    let avgPaceMinPerKm: Double    // average of last 5 walks; 0.0 if no history
    let bestTimeOfDay: String      // "morning" | "afternoon" | "evening" | "unknown"
    let paceTrend: String          // "improving" | "stable" | "declining"
    let thisWeekWalks: Int
    let lastWeekWalks: Int
}
```

The backend Worker receives this richer context; no backend changes required — the Worker
already uses the full context object. Extra fields are simply available in the prompt.

### CoachViewModel

- `refreshContext()` calls `WalkInsightsEngine.analyze()` and populates new fields
- `enqueueAssistantResponse()` passes the enriched context to `apiClient.sendMessage()`

## Affected Files

| File | Change |
|---|---|
| `iWalk AI/Services/WalkInsightsEngine.swift` | NEW |
| `iWalk AI/Views/Components/TieredProgressBar.swift` | Add `insights` param; update `aiInsight` |
| `iWalk AI/ViewModels/DashboardViewModel.swift` | Compute + store `walkInsights` |
| `iWalk AI/Services/CoachAPIClient.swift` | Add fields to `CoachContext` |
| `iWalk AI/ViewModels/CoachViewModel.swift` | Populate new context fields |

## Fallback Behavior

- No walk history: existing behavior unchanged (rule-based insight text, basic coach context)
- Network unavailable: insights still show (local engine is offline-capable)
- Single walk: tier 1 fallback (not enough data for patterns)

## Out of Scope

- Push notifications for Day 4-7 trigger (separate feature)
- Paywall / subscription implementation (separate feature)
- Backend Worker prompt changes (additive — new fields are available without code changes)
