# WeWard-Inspired Feature Pack — Design Spec

## Product Goal

Add a complete gamification layer to iWalk AI inspired by WeWard's proven mechanics, while differentiating through AI coaching integration. The features form a self-reinforcing loop: walk → earn coins → track streaks → progress journey → share achievements → invite friends → walk more.

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Coin system | Virtual coins first, architecture pre-reserves real redemption | Zero ops cost for MVP, can add real rewards later |
| Map exploration | MapKit + virtual journey (US cities) | Fun without external POI data dependency |
| Social | Share cards + local leaderboard mock, CloudKit-ready | Share cards are zero-cost growth; backend comes later |
| Evening review | Dashboard top card, auto-switches after 8 PM | Non-intrusive, natural flow |
| Overall approach | Coin system first, all features as coin producers | Avoids rework; single economic backbone |

## Architecture Overview

```
CoinViewModel (central)
  ├── StepTierEngine → earns coins from step thresholds
  ├── StreakEngine → earns coins from daily consistency
  ├── JourneyEngine → earns coins from distance milestones
  ├── ChallengeEngine (existing) → earns coins from challenges
  ├── BadgeEngine (existing) → earns coins from badge unlocks
  └── EveningReviewEngine → earns coins from viewing review

DashboardView (modified)
  ├── Coin balance (top-right)
  ├── Step tier progress bar (replaces simple progress)
  ├── Streak badge (compact)
  ├── Journey progress card (expandable)
  └── Evening review card (after 8 PM)

ShareService (new)
  └── ImageRenderer → ShareLink
```

All new ViewModels are `@Observable` and composed within existing views. No new Tabs added.

---

## Module 1: Coin Engine

### Data Models

```swift
struct CoinAccount {
    var balance: Int
    var lifetimeEarned: Int
    var lifetimeSpent: Int
}

struct CoinTransaction: Identifiable {
    let id: UUID
    let amount: Int               // positive = earn, negative = spend
    let source: CoinSource
    let description: String
    let timestamp: Date
}

enum CoinSource: String, Codable {
    case stepTier
    case personalGoal
    case streak
    case walkSession
    case milestone
    case challenge
    case badge
    case dailyReview
    case redemption
}
```

### Earning Rules

| Action | Coins | Notes |
|---|---|---|
| Tier 1 (1,500 steps) | +5 | Lowest barrier |
| Tier 2 (3,000 steps) | +8 | |
| Tier 3 (6,500 steps) | +12 | |
| Tier 4 (10,000 steps) | +18 | |
| Tier 5 (20,000 steps) | +25 | Daily cap from tiers |
| Personal goal | +10 | 4-week rolling avg × 1.1 |
| Streak (daily) | +3 × min(days, 10) | Cap +30/day |
| Walk session complete | +5 | Per session |
| Journey milestone | +20 | Reach a city |
| Challenge complete | +50 | High-value, low-frequency |
| Badge unlock | +30 | |
| View evening review | +5 | Engagement incentive |

### Spending (reserved)

- AI coach deep conversations
- Theme/skin unlocks
- Badge display frames
- Future: gift card redemption

### CoinViewModel

```swift
@Observable class CoinViewModel {
    var account: CoinAccount
    var transactions: [CoinTransaction]
    var todayTiersReached: Set<Int>

    func earn(amount: Int, source: CoinSource, description: String) -> CoinTransaction
    func spend(amount: Int, description: String) -> Bool
    func todayEarnings() -> Int
    func checkStepTiers(currentSteps: Int) -> [CoinTransaction]
}
```

### UI

- Dashboard top-right: coin icon + balance with `contentTransition(.numericText)`
- Tier reached: toast animation (reuse existing milestone toast pattern)
- Transaction history: accessible from coin balance tap

---

## Module 2: Multi-Tier Daily Goals

### Data Models

```swift
struct StepTier: Identifiable {
    let id: Int                   // 1-5
    let stepsRequired: Int
    let coinReward: Int
    var isReached: Bool
    var isClaimed: Bool
}

struct PersonalGoal {
    let targetSteps: Int          // 28-day avg × 1.1
    let coinReward: Int           // fixed 10
    var isReached: Bool
}
```

### Integration with DashboardView

- Replace single progress bar with tiered progress bar
- 5 tick marks on the bar at 1.5k / 3k / 6.5k / 10k / 20k
- Each tick: small dot, lights up + bounce animation on reach
- Personal goal shown as green star icon above the bar
- Tap progress bar → expand to show each tier's coin reward

### Flow

`DashboardViewModel` step count changes → `CoinViewModel.checkStepTiers()` → new tier reached → earn coins + toast

---

## Module 3: Streak Enhancement + AI Encouragement

### Data Models

```swift
struct StreakData {
    var currentStreak: Int
    var longestStreak: Int
    var lastCompletedDate: Date?
    var freezeCardsRemaining: Int     // max 3
    var freezeCardsUsed: [Date]

    var isActiveToday: Bool           // reached tier 1 today
    var isAtRisk: Bool                // evening, not yet reached tier 1
}
```

### Rules

- **Qualify:** reach tier 1 (1,500 steps) = day counts
- **Freeze cards:** earn 1 per 7-day streak, hold max 3, auto-use on miss
- **Coins:** +3 × min(streak, 10) daily, cap +30
- **Milestones:** 7 / 14 / 30 / 60 / 100 days → special badge + bonus coins

### AI Coach Integration (CoachViewModel)

| Scenario | AI Behavior |
|---|---|
| New streak milestone | Congratulations + personalized tip |
| 8 PM, not yet qualified | Gentle reminder card on Dashboard |
| Returned after break | Encouragement, no blame, "fresh start" |
| Freeze card used | Confirm + "let's get back tomorrow" |
| 30-day streak | Long-form review + data comparison |

### UI

- Dashboard: compact streak badge (🔥 14) below coin balance, tap for details
- HabitsView: add freeze card UI + milestone progress
- Full-screen celebration on milestone streaks

---

## Module 4: Virtual Journey

### Data Models

```swift
struct VirtualJourney: Identifiable {
    let id: String
    let name: String                  // "New York → Los Angeles"
    let totalDistanceKm: Double
    let milestones: [JourneyMilestone]
    var distanceCoveredKm: Double
    var isCompleted: Bool

    var progress: Double { distanceCoveredKm / totalDistanceKm }
}

struct JourneyMilestone: Identifiable {
    let id: String
    let name: String                  // "Pittsburgh"
    let distanceFromStartKm: Double
    let funFact: String
    let icon: String
    var isReached: Bool
    var reachedDate: Date?
}
```

### Journey Templates (US Cities)

**NY → LA (~4,500 km) — Starter**

| Milestone | Distance | Fun Fact |
|---|---|---|
| Philadelphia | 150 km | "Home of the first US zoo, opened in 1874" |
| Pittsburgh | 500 km | "Has more bridges than any other city — 446!" |
| Indianapolis | 1,100 km | "Hosts the largest single-day sporting event on Earth" |
| St. Louis | 1,500 km | "The Gateway Arch is exactly as wide as it is tall — 630 ft" |
| Oklahoma City | 2,100 km | "State Capitol is the only one with an oil well beneath it" |
| Albuquerque | 2,900 km | "Hosts the world's largest hot air balloon festival" |
| Flagstaff | 3,500 km | "First city named an International Dark Sky City" |
| Los Angeles | 4,500 km | "The Hollywood Sign originally read 'Hollywoodland' in 1923" |

**Pacific Coast: Seattle → San Diego (~2,000 km)**
**Route 66: Chicago → Santa Monica (~3,940 km)**
**Appalachian Trail: Georgia → Maine (~3,500 km)**
**Around the World (40,075 km) — Ultimate**

> Note: Detailed milestones for journeys beyond NY→LA will be defined during implementation. Each journey will have 6-10 milestone cities with fun facts.

### UI

- **Dashboard card:** horizontal route progress, milestone dots, next city name + distance remaining
- **Detail view (push):** MapKit showing route line, animated current position marker, milestone cards
- **Milestone reached:** popup card with city fun fact + +20 coins
- **Journey selection:** shown after completing a journey

### Integration

- `ActiveWalkViewModel` walk ends → distance added to `VirtualJourney.distanceCoveredKm`
- Milestone check → `CoinViewModel.earn()` if new city reached

---

## Module 5: Evening Review

### Data Model

```swift
struct EveningReview {
    let date: Date
    let totalSteps: Int
    let tiersReached: Int
    let coinsEarned: Int
    let streakCount: Int
    let journeyDistanceToday: Double
    let aiSummary: String
    let comparisonToAverage: Int      // % vs 7-day avg
    var isViewed: Bool
}
```

### Trigger

- Local time ≥ 20:00
- Replaces Dashboard top section (step progress + "Start Walking" button)
- Before 20:00: normal daytime mode

### UI Layout

```
┌─────────────────────────────────┐
│  🌙 Today's Review              │
│                                 │
│  8,520 steps  ·  5.8 km        │
│  ████████████░░░ Tier 4 reached │
│                                 │
│  +46 coins earned today  🪙     │
│  🔥 Streak: 14 days            │
│  🗺️ Journey: +5.8 km           │
│     Next: Nanjing, 82 km left  │
│                                 │
│  AI: "Great consistency! You've │
│  been 12% above your weekly     │
│  average. Tomorrow try a morning│
│  walk for better sleep quality."│
│                                 │
│  [ View Details ]  → +5 coins  │
└─────────────────────────────────┘
```

- Dark gradient (deep blue/purple) to differentiate from daytime
- "View Details" expands full stats + claims +5 coins
- Share button at bottom of expanded view

---

## Module 6: Share Cards + Invite

### Share Card Types

```swift
enum ShareCardType {
    case dailySummary
    case streakMilestone
    case journeyMilestone
    case badgeUnlock
    case challengeComplete
    case weeklyReport
}
```

### Implementation

- SwiftUI view → `ImageRenderer` → `UIImage` → `ShareLink`
- Card footer: app logo + "Track your walks with iWalk AI" + App Store link
- Style: consistent with app design system, gradient backgrounds

### Trigger Points

| Moment | Prompt |
|---|---|
| Streak 7/14/30/60/100 | "Share your streak?" |
| Journey city reached | "You reached Pittsburgh! Share?" |
| Badge unlocked | Share button on badge detail |
| Evening review | Share button at bottom |
| Weekly report | Coach pushes report with share |

### Invite Mechanism

- `ShareLink` with App Store URL + personal invite text
- Local invite code: first 6 chars of UUID, stored in `UserDefaults`
- Invite page in Settings/Profile: code display + share button
- Reserved: CloudKit tracking for bidirectional invite rewards

### Leaderboard (existing, unchanged)

- Keep current `BadgesView` leaderboard UI and `LeaderboardEntry` model
- Add `syncSource` field for future CloudKit readiness:

```swift
enum LeaderboardSyncSource {
    case local       // current: mock data
    case cloudKit    // future
}
```

---

## Files Affected

### New Files

| File | Purpose |
|---|---|
| `Models/CoinModels.swift` | CoinAccount, CoinTransaction, CoinSource |
| `Models/StepTierModels.swift` | StepTier, PersonalGoal |
| `Models/StreakModels.swift` | StreakData |
| `Models/JourneyModels.swift` | VirtualJourney, JourneyMilestone, JourneyTemplate |
| `Models/EveningReviewModels.swift` | EveningReview |
| `Models/ShareModels.swift` | ShareCard, ShareCardType, ShareCardStats |
| `ViewModels/CoinViewModel.swift` | Central coin engine |
| `ViewModels/StepTierViewModel.swift` | Tier checking logic |
| `ViewModels/StreakViewModel.swift` | Streak tracking + freeze cards |
| `ViewModels/JourneyViewModel.swift` | Journey progress + milestone checks |
| `ViewModels/EveningReviewViewModel.swift` | Review generation + state |
| `ViewModels/ShareViewModel.swift` | Card rendering + sharing |
| `Views/JourneyDetailView.swift` | Full journey map + milestones |
| `Views/ShareCardView.swift` | Renderable share card templates |
| `Views/Components/TieredProgressBar.swift` | Multi-tier step progress |
| `Views/Components/StreakBadge.swift` | Compact streak display |
| `Views/Components/JourneyCard.swift` | Dashboard journey summary |
| `Views/Components/EveningReviewCard.swift` | Dashboard evening card |
| `Views/Components/CoinToast.swift` | Coin earned animation |

### Modified Files

| File | Changes |
|---|---|
| `Views/DashboardView.swift` | Add coin balance, tiered progress, streak badge, journey card, evening review |
| `Views/HabitsView.swift` | Add freeze card UI, streak milestones |
| `Views/BadgesView.swift` | Connect badge unlocks to coin system, add syncSource |
| `Views/ActiveWalkView.swift` | Post-walk: update journey distance, award session coins |
| `Views/AICoachView.swift` | Add streak-aware messages, evening prompts |
| `ViewModels/DashboardViewModel.swift` | Orchestrate tier checks, evening mode toggle |
| `ViewModels/ActiveWalkViewModel.swift` | Post-walk coin + journey hooks |
| `ViewModels/CoachViewModel.swift` | Streak-aware AI messages |
| `ViewModels/HabitsViewModel.swift` | Freeze card logic |
| `ViewModels/BadgesViewModel.swift` | Coin integration on unlock |
| `Models/WalkModels.swift` | Add LeaderboardSyncSource |
| `DesignSystem/Components.swift` | Add CoinToast, TieredProgressBar components |

---

## Persistence Strategy

All state persisted via `UserDefaults` / `AppStorage` for MVP:

- `CoinAccount` → JSON in UserDefaults
- `[CoinTransaction]` → JSON in UserDefaults (last 100)
- `StreakData` → JSON in UserDefaults
- `VirtualJourney` (active) → JSON in UserDefaults
- `todayTiersReached` → UserDefaults (reset daily)

Future: migrate to SwiftData when models stabilize.

---

## Verification Checklist

- [ ] All coin earning paths tested with mock data
- [ ] Tier progression triggers toast at each threshold
- [ ] Streak increments daily, freeze card auto-applies
- [ ] Journey distance accumulates across walk sessions
- [ ] Evening review appears after 8 PM, daytime mode before
- [ ] Share cards render correctly via ImageRenderer
- [ ] No new Tabs added — all integrated into existing views
- [ ] Animations smooth on iPhone SE (smallest screen)
- [ ] Coin balance updates with numericText transition
- [ ] No force-unwraps or hardcoded secrets
