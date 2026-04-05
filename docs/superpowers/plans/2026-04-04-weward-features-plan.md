# WeWard-Inspired Feature Pack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a full gamification layer (coin engine, tiered goals, streak, virtual journey, evening review, share cards) to the iWalk AI iOS app.

**Architecture:** All features funnel through a central `CoinViewModel` that tracks earnings/spending. Existing ViewModels (`DashboardViewModel`, `ActiveWalkViewModel`, etc.) gain references to shared game-state ViewModels. Persistence uses `UserDefaults` JSON encoding for MVP. No new Tabs — all UI integrates into existing views.

**Tech Stack:** SwiftUI, MapKit (journey detail), `ImageRenderer` (share cards), `@Observable` macro, `UserDefaults`/`AppStorage` persistence, `Codable` for JSON serialization.

**Spec:** `docs/superpowers/specs/2026-04-04-weward-inspired-features-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|---|---|
| `Models/CoinModels.swift` | `CoinAccount`, `CoinTransaction`, `CoinSource` — all Codable |
| `Models/StepTierModels.swift` | `StepTier`, `PersonalGoal` |
| `Models/StreakModels.swift` | `StreakData`, freeze card logic |
| `Models/JourneyModels.swift` | `VirtualJourney`, `JourneyMilestone`, `JourneyTemplate` |
| `Models/EveningReviewModel.swift` | `EveningReview` |
| `Models/ShareModels.swift` | `ShareCardType`, `ShareCardStats` |
| `ViewModels/CoinViewModel.swift` | Central coin engine — earn, spend, tier checks, persistence |
| `ViewModels/StreakViewModel.swift` | Streak tracking, freeze cards, milestone checks |
| `ViewModels/JourneyViewModel.swift` | Journey progress, milestone detection, journey selection |
| `Views/JourneyDetailView.swift` | Full-screen journey with MapKit route + milestone list |
| `Views/Components/TieredProgressBar.swift` | Multi-tier step progress visualization |
| `Views/Components/StreakBadgeView.swift` | Compact streak display for Dashboard |
| `Views/Components/JourneyCard.swift` | Dashboard journey summary card |
| `Views/Components/EveningReviewCard.swift` | Dashboard evening review card |
| `Views/Components/CoinBalanceView.swift` | Coin icon + balance with animation |
| `Views/Components/CoinToast.swift` | "+X coins" floating toast |
| `Views/Components/ShareCardView.swift` | Renderable share card templates |

### Modified Files

| File | Changes |
|---|---|
| `iWalk_AIApp.swift` | Create shared CoinViewModel, StreakViewModel, JourneyViewModel via `.environment()` |
| `Views/DashboardView.swift` | Add coin balance, tiered progress, streak badge, journey card, evening review |
| `ViewModels/DashboardViewModel.swift` | Orchestrate tier checks, evening mode detection |
| `Views/ActiveWalkView.swift` | Post-walk summary adds journey distance + session coins |
| `ViewModels/ActiveWalkViewModel.swift` | Hook into CoinViewModel + JourneyViewModel on walk end |
| `Views/HabitsView.swift` | Add freeze card UI section |
| `ViewModels/HabitsViewModel.swift` | Wire to StreakViewModel for real streak data |
| `Views/BadgesView.swift` | Add share button on badge detail |
| `ViewModels/BadgesViewModel.swift` | Call CoinViewModel on badge unlock |
| `Views/AICoachView.swift` | Add streak-aware messages |
| `ViewModels/CoachViewModel.swift` | Streak-aware AI message generation |
| `DesignSystem/Colors.swift` | Add evening gradient colors |
| `DesignSystem/Components.swift` | Add `AppHeader` coin balance slot |
| `Models/WalkModels.swift` | Add `LeaderboardSyncSource` enum |

---

## Task 1: Coin Data Models

**Files:**
- Create: `iWalk AI/Models/CoinModels.swift`

- [ ] **Step 1: Create CoinModels.swift with all coin types**

```swift
// iWalk AI/Models/CoinModels.swift
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
```

- [ ] **Step 2: Build to verify no compile errors**

Run:
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && export PATH="$DEVELOPER_DIR/usr/bin:$PATH" && xcodebuild build -project "iWalk AI.xcodeproj" -scheme "iWalk AI" -destination "platform=iOS Simulator,name=iPhone 17 Pro" 2>&1 | xcbeautify --quiet
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add "iWalk AI/Models/CoinModels.swift"
git commit -m "feat: add coin system data models"
```

---

## Task 2: Step Tier & Personal Goal Models

**Files:**
- Create: `iWalk AI/Models/StepTierModels.swift`

- [ ] **Step 1: Create StepTierModels.swift**

```swift
// iWalk AI/Models/StepTierModels.swift
import Foundation

struct StepTier: Identifiable, Codable {
    let id: Int
    let stepsRequired: Int
    let coinReward: Int
    var isReached: Bool
    var isClaimed: Bool
    
    static let allTiers: [StepTier] = [
        StepTier(id: 1, stepsRequired: 1_500, coinReward: 5, isReached: false, isClaimed: false),
        StepTier(id: 2, stepsRequired: 3_000, coinReward: 8, isReached: false, isClaimed: false),
        StepTier(id: 3, stepsRequired: 6_500, coinReward: 12, isReached: false, isClaimed: false),
        StepTier(id: 4, stepsRequired: 10_000, coinReward: 18, isReached: false, isClaimed: false),
        StepTier(id: 5, stepsRequired: 20_000, coinReward: 25, isReached: false, isClaimed: false),
    ]
}

struct PersonalGoal: Codable {
    let targetSteps: Int
    let coinReward: Int
    var isReached: Bool
    
    /// Calculate personal goal from 28-day average × 1.1
    static func calculate(from recentDailySteps: [Int]) -> PersonalGoal {
        let avg = recentDailySteps.isEmpty ? 8_000 : recentDailySteps.reduce(0, +) / recentDailySteps.count
        let target = Int(Double(avg) * 1.1)
        return PersonalGoal(targetSteps: target, coinReward: 10, isReached: false)
    }
    
    static let mock = PersonalGoal(targetSteps: 9_350, coinReward: 10, isReached: false)
}
```

- [ ] **Step 2: Build to verify**

Run same build command as Task 1. Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add "iWalk AI/Models/StepTierModels.swift"
git commit -m "feat: add step tier and personal goal models"
```

---

## Task 3: Streak Data Model

**Files:**
- Create: `iWalk AI/Models/StreakModels.swift`

- [ ] **Step 1: Create StreakModels.swift**

```swift
// iWalk AI/Models/StreakModels.swift
import Foundation

struct StreakData: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var lastCompletedDate: Date?
    var freezeCardsRemaining: Int
    var freezeCardsUsed: [Date]
    
    static let empty = StreakData(
        currentStreak: 0,
        longestStreak: 0,
        lastCompletedDate: nil,
        freezeCardsRemaining: 0,
        freezeCardsUsed: []
    )
    
    static let mock = StreakData(
        currentStreak: 14,
        longestStreak: 21,
        lastCompletedDate: Calendar.current.startOfDay(for: .now),
        freezeCardsRemaining: 2,
        freezeCardsUsed: []
    )
    
    var isActiveToday: Bool {
        guard let last = lastCompletedDate else { return false }
        return Calendar.current.isDateInToday(last)
    }
    
    /// True if it's after 8 PM and today is not yet completed
    var isAtRisk: Bool {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour >= 20 && !isActiveToday
    }
    
    /// Streak coin reward: +3 × min(streak, 10)
    var dailyCoinReward: Int {
        3 * min(currentStreak, 10)
    }
    
    /// Streak milestones that award bonus coins + badges
    static let milestones: [Int] = [7, 14, 30, 60, 100]
    
    var nextMilestone: Int? {
        Self.milestones.first { $0 > currentStreak }
    }
    
    var daysToNextMilestone: Int? {
        guard let next = nextMilestone else { return nil }
        return next - currentStreak
    }
    
    /// Mark today as completed, update streak, check freeze cards
    mutating func completeToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        
        if let last = lastCompletedDate {
            let lastDay = calendar.startOfDay(for: last)
            if calendar.isDateInToday(last) {
                return // Already completed today
            }
            let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if daysBetween == 1 {
                // Consecutive day
                currentStreak += 1
            } else if daysBetween == 2 && freezeCardsRemaining > 0 {
                // Missed one day, use freeze card
                freezeCardsRemaining -= 1
                freezeCardsUsed.append(calendar.date(byAdding: .day, value: -1, to: today) ?? today)
                currentStreak += 1
            } else {
                // Streak broken
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }
        
        lastCompletedDate = today
        longestStreak = max(longestStreak, currentStreak)
        
        // Award freeze card every 7-day streak
        if currentStreak > 0 && currentStreak % 7 == 0 && freezeCardsRemaining < 3 {
            freezeCardsRemaining += 1
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run same build command. Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add "iWalk AI/Models/StreakModels.swift"
git commit -m "feat: add streak data model with freeze cards"
```

---

## Task 4: Journey Data Models

**Files:**
- Create: `iWalk AI/Models/JourneyModels.swift`

- [ ] **Step 1: Create JourneyModels.swift**

```swift
// iWalk AI/Models/JourneyModels.swift
import Foundation
import CoreLocation

// MARK: - Journey Milestone

struct JourneyMilestone: Identifiable, Codable {
    let id: String
    let name: String
    let distanceFromStartKm: Double
    let funFact: String
    let icon: String
    let coordinate: CodableCoordinate
    var isReached: Bool
    var reachedDate: Date?
    
    init(id: String = UUID().uuidString, name: String, distanceFromStartKm: Double, funFact: String, icon: String, latitude: Double, longitude: Double, isReached: Bool = false, reachedDate: Date? = nil) {
        self.id = id
        self.name = name
        self.distanceFromStartKm = distanceFromStartKm
        self.funFact = funFact
        self.icon = icon
        self.coordinate = CodableCoordinate(latitude: latitude, longitude: longitude)
        self.isReached = isReached
        self.reachedDate = reachedDate
    }
}

struct CodableCoordinate: Codable {
    let latitude: Double
    let longitude: Double
    
    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Virtual Journey

struct VirtualJourney: Identifiable, Codable {
    let id: String
    let name: String
    let totalDistanceKm: Double
    var milestones: [JourneyMilestone]
    var distanceCoveredKm: Double
    var isCompleted: Bool
    
    var progress: Double {
        min(distanceCoveredKm / totalDistanceKm, 1.0)
    }
    
    var nextMilestone: JourneyMilestone? {
        milestones.first { !$0.isReached }
    }
    
    var distanceToNextMilestone: Double? {
        guard let next = nextMilestone else { return nil }
        return max(next.distanceFromStartKm - distanceCoveredKm, 0)
    }
    
    var reachedMilestones: [JourneyMilestone] {
        milestones.filter(\.isReached)
    }
    
    /// Add distance and check if any new milestones are reached.
    /// Returns newly reached milestones.
    mutating func addDistance(_ km: Double) -> [JourneyMilestone] {
        distanceCoveredKm += km
        var newlyReached: [JourneyMilestone] = []
        
        for i in milestones.indices {
            if !milestones[i].isReached && distanceCoveredKm >= milestones[i].distanceFromStartKm {
                milestones[i].isReached = true
                milestones[i].reachedDate = .now
                newlyReached.append(milestones[i])
            }
        }
        
        if distanceCoveredKm >= totalDistanceKm {
            isCompleted = true
        }
        
        return newlyReached
    }
}

// MARK: - Journey Templates

enum JourneyTemplate: String, CaseIterable, Identifiable {
    case nyToLA = "ny_to_la"
    case pacificCoast = "pacific_coast"
    case route66 = "route_66"
    case appalachianTrail = "appalachian_trail"
    case aroundTheWorld = "around_the_world"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .nyToLA: "New York → Los Angeles"
        case .pacificCoast: "Pacific Coast Highway"
        case .route66: "Route 66"
        case .appalachianTrail: "Appalachian Trail"
        case .aroundTheWorld: "Around the World"
        }
    }
    
    var difficultyLabel: String {
        switch self {
        case .nyToLA: "Starter"
        case .pacificCoast: "Intermediate"
        case .route66: "Advanced"
        case .appalachianTrail: "Challenge"
        case .aroundTheWorld: "Ultimate"
        }
    }
    
    var totalDistanceKm: Double {
        switch self {
        case .nyToLA: 4_500
        case .pacificCoast: 2_000
        case .route66: 3_940
        case .appalachianTrail: 3_500
        case .aroundTheWorld: 40_075
        }
    }
    
    func createJourney() -> VirtualJourney {
        VirtualJourney(
            id: rawValue,
            name: displayName,
            totalDistanceKm: totalDistanceKm,
            milestones: createMilestones(),
            distanceCoveredKm: 0,
            isCompleted: false
        )
    }
    
    private func createMilestones() -> [JourneyMilestone] {
        switch self {
        case .nyToLA:
            return [
                JourneyMilestone(name: "Philadelphia", distanceFromStartKm: 150, funFact: "Home of the first US zoo, opened in 1874.", icon: "building.columns.fill", latitude: 39.9526, longitude: -75.1652),
                JourneyMilestone(name: "Pittsburgh", distanceFromStartKm: 500, funFact: "Has more bridges than any other city in the world — 446!", icon: "arrow.triangle.branch", latitude: 40.4406, longitude: -79.9959),
                JourneyMilestone(name: "Indianapolis", distanceFromStartKm: 1_100, funFact: "Hosts the largest single-day sporting event on Earth.", icon: "flag.checkered", latitude: 39.7684, longitude: -86.1581),
                JourneyMilestone(name: "St. Louis", distanceFromStartKm: 1_500, funFact: "The Gateway Arch is exactly as wide as it is tall — 630 feet.", icon: "archway", latitude: 38.6270, longitude: -90.1994),
                JourneyMilestone(name: "Oklahoma City", distanceFromStartKm: 2_100, funFact: "The State Capitol is the only one with an oil well beneath it.", icon: "drop.fill", latitude: 35.4676, longitude: -97.5164),
                JourneyMilestone(name: "Albuquerque", distanceFromStartKm: 2_900, funFact: "Hosts the world's largest hot air balloon festival.", icon: "balloon.fill", latitude: 35.0844, longitude: -106.6504),
                JourneyMilestone(name: "Flagstaff", distanceFromStartKm: 3_500, funFact: "First city named an International Dark Sky City.", icon: "moon.stars.fill", latitude: 35.1983, longitude: -111.6513),
                JourneyMilestone(name: "Los Angeles", distanceFromStartKm: 4_500, funFact: "The Hollywood Sign originally read 'Hollywoodland' in 1923.", icon: "star.fill", latitude: 34.0522, longitude: -118.2437),
            ]
        case .pacificCoast:
            return [
                JourneyMilestone(name: "Portland", distanceFromStartKm: 280, funFact: "Has more breweries per capita than any city in the world.", icon: "mug.fill", latitude: 45.5152, longitude: -122.6784),
                JourneyMilestone(name: "Eugene", distanceFromStartKm: 460, funFact: "Known as 'Track Town, USA' — birthplace of Nike.", icon: "figure.run", latitude: 44.0521, longitude: -123.0868),
                JourneyMilestone(name: "Crescent City", distanceFromStartKm: 700, funFact: "Gateway to the tallest trees on Earth — the coast redwoods.", icon: "tree.fill", latitude: 41.7558, longitude: -124.2026),
                JourneyMilestone(name: "San Francisco", distanceFromStartKm: 1_050, funFact: "The Golden Gate Bridge's color is officially 'International Orange'.", icon: "bridge", latitude: 37.7749, longitude: -122.4194),
                JourneyMilestone(name: "Big Sur", distanceFromStartKm: 1_250, funFact: "One of only two places in the world where mountains over 1,000m meet the ocean.", icon: "mountain.2.fill", latitude: 36.2704, longitude: -121.8081),
                JourneyMilestone(name: "Santa Barbara", distanceFromStartKm: 1_600, funFact: "Called the 'American Riviera' for its Mediterranean climate.", icon: "sun.max.fill", latitude: 34.4208, longitude: -119.6982),
                JourneyMilestone(name: "San Diego", distanceFromStartKm: 2_000, funFact: "Home to the world's most visited zoo with over 4 million visitors a year.", icon: "pawprint.fill", latitude: 32.7157, longitude: -117.1611),
            ]
        case .route66:
            return [
                JourneyMilestone(name: "Springfield, IL", distanceFromStartKm: 320, funFact: "Abraham Lincoln lived here for 24 years before becoming President.", icon: "building.columns.fill", latitude: 39.7817, longitude: -89.6501),
                JourneyMilestone(name: "St. Louis", distanceFromStartKm: 480, funFact: "The first ice cream cone was served here at the 1904 World's Fair.", icon: "cone.fill", latitude: 38.6270, longitude: -90.1994),
                JourneyMilestone(name: "Tulsa", distanceFromStartKm: 1_100, funFact: "Was once called the 'Oil Capital of the World'.", icon: "drop.fill", latitude: 36.1540, longitude: -95.9928),
                JourneyMilestone(name: "Amarillo", distanceFromStartKm: 1_800, funFact: "Home to Cadillac Ranch — 10 Cadillacs buried nose-first in a field.", icon: "car.fill", latitude: 35.2220, longitude: -101.8313),
                JourneyMilestone(name: "Albuquerque", distanceFromStartKm: 2_400, funFact: "Sits at 5,312 feet elevation — one of the highest major US cities.", icon: "mountain.2.fill", latitude: 35.0844, longitude: -106.6504),
                JourneyMilestone(name: "Flagstaff", distanceFromStartKm: 3_000, funFact: "Pluto was discovered here at the Lowell Observatory in 1930.", icon: "sparkles", latitude: 35.1983, longitude: -111.6513),
                JourneyMilestone(name: "Santa Monica", distanceFromStartKm: 3_940, funFact: "The official western terminus of Route 66 — 'End of the Trail'.", icon: "flag.fill", latitude: 34.0195, longitude: -118.4912),
            ]
        case .appalachianTrail:
            return [
                JourneyMilestone(name: "Springer Mountain, GA", distanceFromStartKm: 0, funFact: "The southern terminus — every thru-hiker starts or ends here.", icon: "flag.fill", latitude: 34.6268, longitude: -84.1938),
                JourneyMilestone(name: "Great Smoky Mountains", distanceFromStartKm: 320, funFact: "The most visited national park in the US with 12+ million visitors.", icon: "cloud.fog.fill", latitude: 35.6532, longitude: -83.5070),
                JourneyMilestone(name: "Shenandoah", distanceFromStartKm: 1_400, funFact: "The park has over 500 miles of trails including 101 miles of the AT.", icon: "leaf.fill", latitude: 38.2929, longitude: -78.6796),
                JourneyMilestone(name: "Harpers Ferry, WV", distanceFromStartKm: 1_700, funFact: "The psychological halfway point and home of the ATC headquarters.", icon: "building.fill", latitude: 39.3254, longitude: -77.7286),
                JourneyMilestone(name: "Delaware Water Gap", distanceFromStartKm: 2_200, funFact: "The gap was carved by the Delaware River over millions of years.", icon: "water.waves", latitude: 40.9676, longitude: -75.1438),
                JourneyMilestone(name: "White Mountains, NH", distanceFromStartKm: 2_900, funFact: "Mount Washington recorded the world's highest wind speed: 231 mph.", icon: "wind", latitude: 44.2706, longitude: -71.3033),
                JourneyMilestone(name: "Mount Katahdin, ME", distanceFromStartKm: 3_500, funFact: "The northern terminus — 'The Greatest Mountain' in the Penobscot language.", icon: "mountain.2.fill", latitude: 45.9044, longitude: -68.9213),
            ]
        case .aroundTheWorld:
            return [
                JourneyMilestone(name: "London", distanceFromStartKm: 5_570, funFact: "Big Ben is actually the name of the bell, not the tower.", icon: "bell.fill", latitude: 51.5074, longitude: -0.1278),
                JourneyMilestone(name: "Paris", distanceFromStartKm: 5_900, funFact: "The Eiffel Tower grows up to 6 inches taller in summer heat.", icon: "building.2.fill", latitude: 48.8566, longitude: 2.3522),
                JourneyMilestone(name: "Cairo", distanceFromStartKm: 9_000, funFact: "The Great Pyramid was the tallest structure for 3,800 years.", icon: "triangle.fill", latitude: 30.0444, longitude: 31.2357),
                JourneyMilestone(name: "Dubai", distanceFromStartKm: 11_000, funFact: "The Burj Khalifa is so tall you can watch 2 sunsets from it.", icon: "building.fill", latitude: 25.2048, longitude: 55.2708),
                JourneyMilestone(name: "Mumbai", distanceFromStartKm: 14_000, funFact: "Home to the world's most expensive private residence.", icon: "house.fill", latitude: 19.0760, longitude: 72.8777),
                JourneyMilestone(name: "Bangkok", distanceFromStartKm: 18_000, funFact: "Bangkok's full ceremonial name has 168 characters.", icon: "sparkles", latitude: 13.7563, longitude: 100.5018),
                JourneyMilestone(name: "Tokyo", distanceFromStartKm: 22_000, funFact: "Has more Michelin-starred restaurants than any city on Earth.", icon: "fork.knife", latitude: 35.6762, longitude: 139.6503),
                JourneyMilestone(name: "Sydney", distanceFromStartKm: 30_000, funFact: "The Opera House roof is covered with over 1 million tiles.", icon: "music.note", latitude: -33.8688, longitude: 151.2093),
                JourneyMilestone(name: "Home", distanceFromStartKm: 40_075, funFact: "You walked around the entire planet. Legendary.", icon: "globe.americas.fill", latitude: 40.7128, longitude: -74.0060),
            ]
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run same build command. Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add "iWalk AI/Models/JourneyModels.swift"
git commit -m "feat: add virtual journey models with US city routes"
```

---

## Task 5: Evening Review & Share Models

**Files:**
- Create: `iWalk AI/Models/EveningReviewModel.swift`
- Create: `iWalk AI/Models/ShareModels.swift`

- [ ] **Step 1: Create EveningReviewModel.swift**

```swift
// iWalk AI/Models/EveningReviewModel.swift
import Foundation

struct EveningReview: Codable {
    let date: Date
    let totalSteps: Int
    let tiersReached: Int
    let coinsEarned: Int
    let streakCount: Int
    let journeyDistanceToday: Double
    let journeyNextCity: String?
    let journeyDistanceRemaining: Double?
    let aiSummary: String
    let comparisonToAverage: Int
    var isViewed: Bool
    
    static func generate(
        steps: Int,
        tiers: Int,
        coins: Int,
        streak: Int,
        journeyDistance: Double,
        nextCity: String?,
        distanceRemaining: Double?,
        weeklyAvgSteps: Int
    ) -> EveningReview {
        let comparison = weeklyAvgSteps > 0
            ? Int((Double(steps - weeklyAvgSteps) / Double(weeklyAvgSteps)) * 100)
            : 0
        
        let summary = generateAISummary(
            steps: steps,
            comparison: comparison,
            streak: streak
        )
        
        return EveningReview(
            date: .now,
            totalSteps: steps,
            tiersReached: tiers,
            coinsEarned: coins,
            streakCount: streak,
            journeyDistanceToday: journeyDistance,
            journeyNextCity: nextCity,
            journeyDistanceRemaining: distanceRemaining,
            aiSummary: summary,
            comparisonToAverage: comparison,
            isViewed: false
        )
    }
    
    private static func generateAISummary(steps: Int, comparison: Int, streak: Int) -> String {
        var parts: [String] = []
        
        if comparison > 0 {
            parts.append("You're \(comparison)% above your weekly average — great consistency!")
        } else if comparison < -10 {
            parts.append("A lighter day, but every step counts.")
        } else {
            parts.append("Solid effort — right on track with your weekly pace.")
        }
        
        if streak >= 7 {
            parts.append("Your \(streak)-day streak shows real commitment.")
        }
        
        let tips = [
            "Try a morning walk tomorrow for better sleep quality.",
            "Walking after meals helps regulate blood sugar.",
            "A brisk 10-minute walk boosts energy for 2 hours.",
            "Outdoor walks in nature reduce stress hormones by 15%.",
        ]
        parts.append(tips[abs(steps) % tips.count])
        
        return parts.joined(separator: " ")
    }
}
```

- [ ] **Step 2: Create ShareModels.swift**

```swift
// iWalk AI/Models/ShareModels.swift
import Foundation

enum ShareCardType: String {
    case dailySummary
    case streakMilestone
    case journeyMilestone
    case badgeUnlock
    case challengeComplete
    case weeklyReport
    
    var defaultHeadline: String {
        switch self {
        case .dailySummary: "Daily Achievement"
        case .streakMilestone: "Streak Milestone!"
        case .journeyMilestone: "Journey Progress"
        case .badgeUnlock: "Badge Unlocked!"
        case .challengeComplete: "Challenge Complete!"
        case .weeklyReport: "Weekly Report"
        }
    }
}

struct ShareCardStats {
    let type: ShareCardType
    let headline: String
    let steps: Int?
    let distance: Double?
    let coins: Int?
    let extraLine: String?
    
    static func dailySummary(steps: Int, distance: Double, coins: Int) -> ShareCardStats {
        ShareCardStats(
            type: .dailySummary,
            headline: "\(steps.formatted()) Steps Today!",
            steps: steps,
            distance: distance,
            coins: coins,
            extraLine: nil
        )
    }
    
    static func streakMilestone(days: Int) -> ShareCardStats {
        ShareCardStats(
            type: .streakMilestone,
            headline: "\(days)-Day Streak!",
            steps: nil,
            distance: nil,
            coins: nil,
            extraLine: "Walking every day for \(days) days straight"
        )
    }
    
    static func journeyMilestone(cityName: String, totalDistance: Double) -> ShareCardStats {
        ShareCardStats(
            type: .journeyMilestone,
            headline: "Reached \(cityName)!",
            steps: nil,
            distance: totalDistance,
            coins: nil,
            extraLine: "Walked the equivalent of \(String(format: "%.0f", totalDistance)) km"
        )
    }
    
    static func badgeUnlock(badgeName: String) -> ShareCardStats {
        ShareCardStats(
            type: .badgeUnlock,
            headline: badgeName,
            steps: nil,
            distance: nil,
            coins: nil,
            extraLine: "New badge unlocked!"
        )
    }
}
```

- [ ] **Step 3: Build to verify**

Run same build command. Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add "iWalk AI/Models/EveningReviewModel.swift" "iWalk AI/Models/ShareModels.swift"
git commit -m "feat: add evening review and share card models"
```

---

## Task 6: CoinViewModel

**Files:**
- Create: `iWalk AI/ViewModels/CoinViewModel.swift`

- [ ] **Step 1: Create CoinViewModel.swift**

```swift
// iWalk AI/ViewModels/CoinViewModel.swift
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
    
    init() {
        // Load from UserDefaults
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
        
        // Reset tiers daily
        let savedDate = UserDefaults.standard.string(forKey: tiersDateKey) ?? ""
        let todayStr = Self.todayString()
        if savedDate == todayStr,
           let data = UserDefaults.standard.data(forKey: todayTiersKey),
           let saved = try? JSONDecoder().decode([StepTier].self, from: data) {
            self.todayTiers = saved
        } else {
            self.todayTiers = StepTier.allTiers
        }
        
        self.personalGoal = .mock
    }
    
    // MARK: - Earn
    
    @discardableResult
    func earn(amount: Int, source: CoinSource, description: String) -> CoinTransaction {
        let tx = CoinTransaction(amount: amount, source: source, description: description)
        account.earn(amount)
        transactions.insert(tx, at: 0)
        
        // Keep only last 200 transactions
        if transactions.count > 200 {
            transactions = Array(transactions.prefix(200))
        }
        
        // Show toast
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
    
    // MARK: - Step Tier Checks
    
    /// Check current steps against tiers, earn coins for newly reached tiers.
    /// Returns the list of newly reached tier IDs.
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
        
        // Check personal goal
        if !personalGoal.isReached && currentSteps >= personalGoal.targetSteps {
            personalGoal.isReached = true
            earn(
                amount: personalGoal.coinReward,
                source: .personalGoal,
                description: "Personal goal: \(personalGoal.targetSteps.formatted()) steps"
            )
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
    
    private static func todayString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: .now)
    }
}
```

- [ ] **Step 2: Build to verify**

Run same build command. Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add "iWalk AI/ViewModels/CoinViewModel.swift"
git commit -m "feat: add CoinViewModel with tier checks and persistence"
```

---

## Task 7: StreakViewModel

**Files:**
- Create: `iWalk AI/ViewModels/StreakViewModel.swift`

- [ ] **Step 1: Create StreakViewModel.swift**

```swift
// iWalk AI/ViewModels/StreakViewModel.swift
import SwiftUI

@Observable
final class StreakViewModel {
    var streak: StreakData
    
    // Toast state for streak milestones
    var showMilestoneToast = false
    var reachedMilestone: Int?
    
    private let storageKey = "iw_streak_data"
    
    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(StreakData.self, from: data) {
            self.streak = saved
        } else {
            self.streak = .mock // Use mock for MVP, .empty for production
        }
    }
    
    /// Call when user reaches tier 1 (1,500 steps) for the first time today.
    /// Returns the coin reward for the streak.
    func completeTodayIfNeeded(coinVM: CoinViewModel) {
        guard !streak.isActiveToday else { return }
        
        let previousStreak = streak.currentStreak
        streak.completeToday()
        
        // Award streak coins
        let reward = streak.dailyCoinReward
        if reward > 0 {
            coinVM.earn(
                amount: reward,
                source: .streak,
                description: "\(streak.currentStreak)-day streak bonus"
            )
        }
        
        // Check for milestone
        if StreakData.milestones.contains(streak.currentStreak) && streak.currentStreak > previousStreak {
            reachedMilestone = streak.currentStreak
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showMilestoneToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                withAnimation(.easeOut(duration: 0.3)) {
                    self?.showMilestoneToast = false
                }
            }
        }
        
        save()
    }
    
    /// Use a freeze card manually
    func useFreezeCard() {
        guard streak.freezeCardsRemaining > 0 else { return }
        streak.freezeCardsRemaining -= 1
        save()
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(streak) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run same build command. Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add "iWalk AI/ViewModels/StreakViewModel.swift"
git commit -m "feat: add StreakViewModel with freeze cards and milestones"
```

---

## Task 8: JourneyViewModel

**Files:**
- Create: `iWalk AI/ViewModels/JourneyViewModel.swift`

- [ ] **Step 1: Create JourneyViewModel.swift**

```swift
// iWalk AI/ViewModels/JourneyViewModel.swift
import SwiftUI

@Observable
final class JourneyViewModel {
    var activeJourney: VirtualJourney?
    var completedJourneys: [String] // journey IDs
    var todayDistanceKm: Double = 0
    
    // UI state
    var showMilestonePopup = false
    var reachedMilestone: JourneyMilestone?
    var showJourneySelection = false
    
    private let journeyKey = "iw_active_journey"
    private let completedKey = "iw_completed_journeys"
    
    init() {
        if let data = UserDefaults.standard.data(forKey: journeyKey),
           let saved = try? JSONDecoder().decode(VirtualJourney.self, from: data) {
            self.activeJourney = saved
        } else {
            // Default: start with NY → LA
            self.activeJourney = JourneyTemplate.nyToLA.createJourney()
        }
        
        if let data = UserDefaults.standard.data(forKey: completedKey),
           let saved = try? JSONDecoder().decode([String].self, from: data) {
            self.completedJourneys = saved
        } else {
            self.completedJourneys = []
        }
    }
    
    /// Add walk distance to the journey. Returns newly reached milestones.
    func addWalkDistance(_ km: Double, coinVM: CoinViewModel) -> [JourneyMilestone] {
        guard var journey = activeJourney else { return [] }
        todayDistanceKm += km
        
        let newMilestones = journey.addDistance(km)
        activeJourney = journey
        
        // Award coins for each new milestone
        for milestone in newMilestones {
            coinVM.earn(
                amount: 20,
                source: .journeyMilestone,
                description: "Reached \(milestone.name)"
            )
        }
        
        // Show popup for last milestone reached
        if let last = newMilestones.last {
            reachedMilestone = last
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showMilestonePopup = true
            }
        }
        
        // Check if journey completed
        if journey.isCompleted {
            completedJourneys.append(journey.id)
            saveCompleted()
            // Show journey selection after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.showJourneySelection = true
            }
        }
        
        saveJourney()
        return newMilestones
    }
    
    func selectJourney(_ template: JourneyTemplate) {
        activeJourney = template.createJourney()
        showJourneySelection = false
        saveJourney()
    }
    
    var availableJourneys: [JourneyTemplate] {
        JourneyTemplate.allCases.filter { !completedJourneys.contains($0.rawValue) }
    }
    
    // MARK: - Persistence
    
    private func saveJourney() {
        if let journey = activeJourney,
           let data = try? JSONEncoder().encode(journey) {
            UserDefaults.standard.set(data, forKey: journeyKey)
        }
    }
    
    private func saveCompleted() {
        if let data = try? JSONEncoder().encode(completedJourneys) {
            UserDefaults.standard.set(data, forKey: completedKey)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run same build command. Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add "iWalk AI/ViewModels/JourneyViewModel.swift"
git commit -m "feat: add JourneyViewModel with distance tracking and milestones"
```

---

## Task 9: Coin UI Components

**Files:**
- Create: `iWalk AI/Views/Components/CoinBalanceView.swift`
- Create: `iWalk AI/Views/Components/CoinToast.swift`

- [ ] **Step 1: Create CoinBalanceView.swift**

```swift
// iWalk AI/Views/Components/CoinBalanceView.swift
import SwiftUI

struct CoinBalanceView: View {
    let balance: Int
    var showLabel: Bool = false
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.iwTertiaryContainer)
                .overlay(
                    Text("$")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                )
            Text("\(balance)")
                .font(IWFont.labelLarge())
                .fontWeight(.semibold)
                .foregroundStyle(Color.iwOnSurface)
                .contentTransition(.numericText())
            if showLabel {
                Text("coins")
                    .font(IWFont.labelSmall())
                    .foregroundStyle(Color.iwOutline)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.iwSurfaceContainerLow)
        .clipShape(Capsule())
    }
}
```

- [ ] **Step 2: Create CoinToast.swift**

```swift
// iWalk AI/Views/Components/CoinToast.swift
import SwiftUI

struct CoinToast: View {
    let amount: Int
    let source: CoinSource
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: source.icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.iwTertiaryContainer)
            
            Text("+\(amount)")
                .font(IWFont.titleMedium())
                .fontWeight(.bold)
                .foregroundStyle(Color.iwTertiaryContainer)
            
            Image(systemName: "circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.iwTertiaryContainer)
                .overlay(
                    Text("$")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.iwOnSurface.opacity(0.9))
        .clipShape(Capsule())
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
```

- [ ] **Step 3: Build to verify**

Run same build command. Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add "iWalk AI/Views/Components/CoinBalanceView.swift" "iWalk AI/Views/Components/CoinToast.swift"
git commit -m "feat: add coin balance and toast UI components"
```

---

## Task 10: TieredProgressBar Component

**Files:**
- Create: `iWalk AI/Views/Components/TieredProgressBar.swift`

- [ ] **Step 1: Create TieredProgressBar.swift**

This replaces the milestone dots on the existing `WalkingPathProgress` with tier markers.

```swift
// iWalk AI/Views/Components/TieredProgressBar.swift
import SwiftUI

struct TieredProgressBar: View {
    let currentSteps: Int
    let goalSteps: Int
    let tiers: [StepTier]
    let personalGoal: PersonalGoal?
    var animatedProgress: Double?
    
    private var progress: Double {
        animatedProgress ?? min(Double(currentSteps) / Double(max(goalSteps, 1)), 1.0)
    }
    
    // Use tier 5 (20k) as the visual max
    private var visualMax: Int { 20_000 }
    
    private func tierPosition(_ tier: StepTier) -> Double {
        min(Double(tier.stepsRequired) / Double(visualMax), 1.0)
    }
    
    private var personalGoalPosition: Double? {
        guard let pg = personalGoal else { return nil }
        return min(Double(pg.targetSteps) / Double(visualMax), 1.0)
    }
    
    private var walkerPosition: Double {
        min(Double(currentSteps) / Double(visualMax), 1.0)
    }
    
    var body: some View {
        VStack(spacing: 14) {
            // Step count
            HStack {
                Text(currentSteps.formatted())
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.iwPrimary)
                    .contentTransition(.numericText())
                Text("/ \(goalSteps.formatted()) steps")
                    .font(IWFont.bodyMedium())
                    .foregroundStyle(Color.iwOutline)
                Spacer()
            }
            
            // Progress track with tier marks
            GeometryReader { geo in
                let trackWidth = geo.size.width
                let trackY: CGFloat = 20
                
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.iwSurfaceContainerHigh)
                        .frame(height: 8)
                        .position(x: trackWidth / 2, y: trackY)
                    
                    // Filled track
                    if walkerPosition > 0.005 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.iwPrimaryGradient)
                            .frame(width: trackWidth * walkerPosition, height: 8)
                            .position(x: (trackWidth * walkerPosition) / 2, y: trackY)
                    }
                    
                    // Tier markers
                    ForEach(tiers) { tier in
                        let x = trackWidth * tierPosition(tier)
                        
                        Circle()
                            .fill(tier.isReached ? Color.iwPrimary : Color.iwSurfaceContainerHighest)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .stroke(Color.iwSurfaceContainerLowest, lineWidth: 2)
                            )
                            .scaleEffect(tier.isReached ? 1.0 : 0.85)
                            .position(x: x, y: trackY)
                        
                        // Tier label below
                        Text(tierLabel(tier.stepsRequired))
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(tier.isReached ? Color.iwPrimary : Color.iwOutlineVariant)
                            .position(x: x, y: trackY + 18)
                        
                        // Coin reward above (only for reached tiers)
                        if tier.isReached {
                            Text("+\(tier.coinReward)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.iwTertiaryContainer)
                                .position(x: x, y: trackY - 16)
                        }
                    }
                    
                    // Personal goal star
                    if let pgPos = personalGoalPosition {
                        let pgX = trackWidth * pgPos
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(personalGoal?.isReached == true ? Color.iwPrimary : Color.iwTertiary)
                            .position(x: pgX, y: trackY - 16)
                    }
                }
            }
            .frame(height: 50)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(currentSteps) of \(goalSteps) steps")
    }
    
    private func tierLabel(_ steps: Int) -> String {
        if steps >= 1000 {
            return "\(steps / 1000)k"
        }
        return "\(steps)"
    }
}
```

- [ ] **Step 2: Build to verify**

Run same build command. Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add "iWalk AI/Views/Components/TieredProgressBar.swift"
git commit -m "feat: add tiered progress bar component"
```

---

## Task 11: Streak Badge & Journey Card Components

**Files:**
- Create: `iWalk AI/Views/Components/StreakBadgeView.swift`
- Create: `iWalk AI/Views/Components/JourneyCard.swift`

- [ ] **Step 1: Create StreakBadgeView.swift**

```swift
// iWalk AI/Views/Components/StreakBadgeView.swift
import SwiftUI

struct StreakBadgeView: View {
    let streak: StreakData
    var compact: Bool = true
    
    var body: some View {
        if compact {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(streak.currentStreak > 0 ? Color.iwTertiaryContainer : Color.iwOutlineVariant)
                Text("\(streak.currentStreak)")
                    .font(IWFont.labelLarge())
                    .fontWeight(.bold)
                    .foregroundStyle(Color.iwOnSurface)
                    .contentTransition(.numericText())
                if !compact {
                    Text("day streak")
                        .font(IWFont.labelSmall())
                        .foregroundStyle(Color.iwOutline)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.iwSurfaceContainerLow)
            .clipShape(Capsule())
        } else {
            expandedView
        }
    }
    
    private var expandedView: some View {
        InfoCard(backgroundColor: .iwSurfaceContainerLowest) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.iwTertiaryContainer)
                    Text("\(streak.currentStreak) Day Streak")
                        .font(IWFont.titleMedium())
                        .foregroundStyle(Color.iwOnSurface)
                    Spacer()
                    if let next = streak.nextMilestone, let days = streak.daysToNextMilestone {
                        Text("\(days)d to \(next)-day")
                            .font(IWFont.labelSmall())
                            .foregroundStyle(Color.iwOutline)
                    }
                }
                
                HStack(spacing: 16) {
                    Label("Best: \(streak.longestStreak)d", systemImage: "trophy.fill")
                        .font(IWFont.labelMedium())
                        .foregroundStyle(Color.iwOutline)
                    
                    if streak.freezeCardsRemaining > 0 {
                        Label("\(streak.freezeCardsRemaining) freeze", systemImage: "snowflake")
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwSecondary)
                    }
                }
                
                if streak.isAtRisk {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                        Text("Walk 1,500 steps to keep your streak!")
                            .font(IWFont.labelMedium())
                    }
                    .foregroundStyle(Color.iwTertiary)
                    .padding(.top, 4)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Create JourneyCard.swift**

```swift
// iWalk AI/Views/Components/JourneyCard.swift
import SwiftUI

struct JourneyCard: View {
    let journey: VirtualJourney
    
    var body: some View {
        InfoCard(backgroundColor: .iwSurfaceContainerLowest) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "map.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.iwSecondary)
                    Text(journey.name)
                        .font(IWFont.labelLarge())
                        .foregroundStyle(Color.iwOnSurface)
                    Spacer()
                    Text("\(Int(journey.progress * 100))%")
                        .font(IWFont.labelMedium())
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.iwPrimary)
                        .contentTransition(.numericText())
                }
                
                // Progress bar with milestone dots
                GeometryReader { geo in
                    let w = geo.size.width
                    
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.iwSurfaceContainerHigh)
                            .frame(height: 6)
                        
                        // Filled
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [.iwSecondary, .iwSecondaryContainer],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: w * journey.progress, height: 6)
                        
                        // Milestone dots
                        ForEach(journey.milestones) { m in
                            let pos = m.distanceFromStartKm / journey.totalDistanceKm
                            Circle()
                                .fill(m.isReached ? Color.iwSecondary : Color.iwSurfaceContainerHighest)
                                .frame(width: 8, height: 8)
                                .offset(x: w * pos - 4)
                        }
                    }
                }
                .frame(height: 10)
                
                // Next city info
                if let next = journey.nextMilestone, let dist = journey.distanceToNextMilestone {
                    HStack(spacing: 6) {
                        Image(systemName: next.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.iwSecondary)
                        Text("Next: \(next.name)")
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwOnSurface)
                        Spacer()
                        Text(String(format: "%.0f km away", dist))
                            .font(IWFont.labelSmall())
                            .foregroundStyle(Color.iwOutline)
                    }
                } else if journey.isCompleted {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.iwPrimary)
                        Text("Journey Complete!")
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwPrimary)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify**

Run same build command. Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add "iWalk AI/Views/Components/StreakBadgeView.swift" "iWalk AI/Views/Components/JourneyCard.swift"
git commit -m "feat: add streak badge and journey card components"
```

---

## Task 12: Evening Review Card Component

**Files:**
- Create: `iWalk AI/Views/Components/EveningReviewCard.swift`
- Modify: `iWalk AI/DesignSystem/Colors.swift` (add evening gradient)

- [ ] **Step 1: Add evening colors to Colors.swift**

Add after the existing `iwPrimaryGradient` in `Colors.swift:59-66`:

```swift
    static var iwEveningGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x1A1A3E), Color(hex: 0x2D1B4E)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static let iwEvening = Color(hex: 0x1A1A3E)
    static let iwEveningAccent = Color(hex: 0x9B8EC4)
```

- [ ] **Step 2: Create EveningReviewCard.swift**

```swift
// iWalk AI/Views/Components/EveningReviewCard.swift
import SwiftUI

struct EveningReviewCard: View {
    let review: EveningReview
    let onViewDetails: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.iwEveningAccent)
                Text("Today's Review")
                    .font(IWFont.titleMedium())
                    .foregroundStyle(.white)
                Spacer()
            }
            
            // Main stats
            HStack(spacing: 4) {
                Text(review.totalSteps.formatted())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("steps")
                    .font(IWFont.bodyMedium())
                    .foregroundStyle(.white.opacity(0.7))
                Text("·")
                    .foregroundStyle(.white.opacity(0.5))
                Text(String(format: "%.1f km", Double(review.totalSteps) / 1400.0))
                    .font(IWFont.bodyMedium())
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            // Tier progress
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { tier in
                    Circle()
                        .fill(tier <= review.tiersReached ? Color.iwPrimaryContainer : Color.white.opacity(0.2))
                        .frame(width: 8, height: 8)
                }
                Text("Tier \(review.tiersReached) reached")
                    .font(IWFont.labelSmall())
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            // Stats row
            HStack(spacing: 16) {
                Label("+\(review.coinsEarned)", systemImage: "circle.fill")
                    .font(IWFont.labelMedium())
                    .foregroundStyle(Color.iwTertiaryContainer)
                
                Label("\(review.streakCount)d", systemImage: "flame.fill")
                    .font(IWFont.labelMedium())
                    .foregroundStyle(Color.iwTertiaryContainer)
                
                if review.journeyDistanceToday > 0 {
                    Label(String(format: "+%.1f km", review.journeyDistanceToday), systemImage: "map.fill")
                        .font(IWFont.labelMedium())
                        .foregroundStyle(Color.iwSecondaryContainer)
                }
            }
            
            // Journey next city
            if let city = review.journeyNextCity, let dist = review.journeyDistanceRemaining {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11))
                    Text("Next: \(city), \(String(format: "%.0f", dist)) km left")
                        .font(IWFont.labelSmall())
                }
                .foregroundStyle(.white.opacity(0.6))
            }
            
            // AI Summary
            Text(review.aiSummary)
                .font(IWFont.bodyMedium())
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(2)
            
            // View Details button
            Button(action: onViewDetails) {
                HStack {
                    Text("View Details")
                        .font(IWFont.labelLarge())
                        .fontWeight(.semibold)
                    Spacer()
                    if !review.isViewed {
                        Text("+5 coins")
                            .font(IWFont.labelSmall())
                            .foregroundStyle(Color.iwTertiaryContainer)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .background(Color.iwEveningGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
```

- [ ] **Step 3: Build to verify**

Run same build command. Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add "iWalk AI/DesignSystem/Colors.swift" "iWalk AI/Views/Components/EveningReviewCard.swift"
git commit -m "feat: add evening review card with dark gradient theme"
```

---

## Task 13: Share Card View

**Files:**
- Create: `iWalk AI/Views/Components/ShareCardView.swift`

- [ ] **Step 1: Create ShareCardView.swift**

```swift
// iWalk AI/Views/Components/ShareCardView.swift
import SwiftUI

struct ShareCardView: View {
    let stats: ShareCardStats
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Icon
            Image(systemName: iconForType(stats.type))
                .font(.system(size: 40))
                .foregroundStyle(.white)
            
            // Headline
            Text(stats.headline)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            
            // Stats
            if let steps = stats.steps {
                HStack(spacing: 16) {
                    if let distance = stats.distance {
                        VStack(spacing: 2) {
                            Text(String(format: "%.1f", distance))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("km")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                    }
                    VStack(spacing: 2) {
                        Text(steps.formatted())
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("steps")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    if let coins = stats.coins {
                        VStack(spacing: 2) {
                            Text("+\(coins)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("coins")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
            
            // Extra line
            if let extra = stats.extraLine {
                Text(extra)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Footer
            HStack(spacing: 6) {
                Circle()
                    .fill(.white)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "figure.walk")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.iwPrimary)
                    )
                Text("iWalk AI")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 8)
        }
        .frame(width: 360, height: 480)
        .background(gradientForType(stats.type))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    private func iconForType(_ type: ShareCardType) -> String {
        switch type {
        case .dailySummary: "figure.walk"
        case .streakMilestone: "flame.fill"
        case .journeyMilestone: "mappin.and.ellipse"
        case .badgeUnlock: "medal.fill"
        case .challengeComplete: "trophy.fill"
        case .weeklyReport: "chart.bar.fill"
        }
    }
    
    private func gradientForType(_ type: ShareCardType) -> LinearGradient {
        switch type {
        case .dailySummary, .weeklyReport:
            return LinearGradient(colors: [.iwPrimary, Color(hex: 0x004D3A)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .streakMilestone:
            return LinearGradient(colors: [.iwTertiary, Color(hex: 0x6B3500)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .journeyMilestone:
            return LinearGradient(colors: [.iwSecondary, Color(hex: 0x064B63)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .badgeUnlock, .challengeComplete:
            return LinearGradient(colors: [Color(hex: 0x6B4FA0), Color(hex: 0x3D2D6B)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Share Helper

struct ShareCardRenderer {
    @MainActor
    static func renderImage(stats: ShareCardStats) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(stats: stats))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
```

- [ ] **Step 2: Build to verify**

Run same build command. Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add "iWalk AI/Views/Components/ShareCardView.swift"
git commit -m "feat: add share card view with image renderer"
```

---

## Task 14: Wire Shared ViewModels into App Entry Point

**Files:**
- Modify: `iWalk AI/iWalk_AIApp.swift`

- [ ] **Step 1: Read current iWalk_AIApp.swift**

Read `iWalk AI/iWalk_AIApp.swift` to see current structure.

- [ ] **Step 2: Update iWalk_AIApp.swift to create and inject shared ViewModels**

The shared ViewModels (`CoinViewModel`, `StreakViewModel`, `JourneyViewModel`) need to be created at the app level and passed down via SwiftUI `.environment()`. Since `@Observable` classes work with `@Environment`, we use custom environment keys.

Add to `iWalk_AIApp.swift`:

```swift
import SwiftUI

// MARK: - Environment Keys

struct CoinViewModelKey: EnvironmentKey {
    static let defaultValue = CoinViewModel()
}

struct StreakViewModelKey: EnvironmentKey {
    static let defaultValue = StreakViewModel()
}

struct JourneyViewModelKey: EnvironmentKey {
    static let defaultValue = JourneyViewModel()
}

extension EnvironmentValues {
    var coinVM: CoinViewModel {
        get { self[CoinViewModelKey.self] }
        set { self[CoinViewModelKey.self] = newValue }
    }
    
    var streakVM: StreakViewModel {
        get { self[StreakViewModelKey.self] }
        set { self[StreakViewModelKey.self] = newValue }
    }
    
    var journeyVM: JourneyViewModel {
        get { self[JourneyViewModelKey.self] }
        set { self[JourneyViewModelKey.self] = newValue }
    }
}

@main
struct iWalk_AIApp: App {
    @State private var coinVM = CoinViewModel()
    @State private var streakVM = StreakViewModel()
    @State private var journeyVM = JourneyViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.coinVM, coinVM)
                .environment(\.streakVM, streakVM)
                .environment(\.journeyVM, journeyVM)
        }
    }
}
```

- [ ] **Step 3: Build to verify**

Run same build command. Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add "iWalk AI/iWalk_AIApp.swift"
git commit -m "feat: inject shared coin, streak, journey ViewModels via environment"
```

---

## Task 15: Update DashboardView — Integrate All New Components

**Files:**
- Modify: `iWalk AI/Views/DashboardView.swift`
- Modify: `iWalk AI/ViewModels/DashboardViewModel.swift`

- [ ] **Step 1: Update DashboardViewModel with evening mode and tier integration**

Replace `DashboardViewModel` with:

```swift
import SwiftUI

@Observable
final class DashboardViewModel {
    var user = UserProfile.mock
    var todayStats = DailyStats.mockToday
    var weeklyActivity = DailyStats.mockWeek
    var healthTips = HealthTip.mockTips
    var currentTipIndex = 0

    // Animation states
    var animatedProgress: Double = 0
    var animatedSteps: Int = 0
    var showHistory = false
    var showActiveWalk = false
    
    // Evening review
    var eveningReview: EveningReview?
    var showEveningDetails = false

    var isWalking: Bool { showActiveWalk }
    var stepGoal: Int { user.dailyStepGoal }
    var currentSteps: Int { todayStats.steps }
    var targetProgress: Double { min(Double(currentSteps) / Double(stepGoal), 1.0) }
    
    var isEveningMode: Bool {
        Calendar.current.component(.hour, from: .now) >= 20
    }

    var currentTip: HealthTip {
        healthTips[currentTipIndex % healthTips.count]
    }

    var todayWeekdayIndex: Int {
        Calendar.current.component(.weekday, from: .now) - 1
    }

    var chartData: [CGFloat] {
        let maxSteps = CGFloat(weeklyActivity.map(\.steps).max() ?? 1)
        return weeklyActivity.map { CGFloat($0.steps) / maxSteps }
    }

    var chartLabels: [String] {
        weeklyActivity.map(\.shortDayName)
    }
    
    var weeklyAvgSteps: Int {
        let total = weeklyActivity.map(\.steps).reduce(0, +)
        return weeklyActivity.isEmpty ? 0 : total / weeklyActivity.count
    }

    func animateOnAppear() {
        withAnimation(.easeOut(duration: 1.2)) {
            animatedProgress = targetProgress
        }
        animateStepCount()
    }

    private func animateStepCount() {
        let duration = 1.2
        let steps = 40
        let stepInterval = duration / Double(steps)
        let stepIncrement = currentSteps / max(steps, 1)

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepInterval * Double(i)) { [weak self] in
                guard let self else { return }
                if i == steps {
                    self.animatedSteps = self.currentSteps
                } else {
                    self.animatedSteps = stepIncrement * i
                }
            }
        }
    }

    func startWalking() {
        showActiveWalk = true
    }

    func onWalkCompleted(session: WalkSession) {
        todayStats.steps = session.totalSteps
        todayStats.calories = todayStats.steps / 20
        todayStats.distanceKm = Double(todayStats.steps) / 1400.0
        todayStats.activeMinutes = todayStats.steps / 200

        animatedSteps = todayStats.steps
        withAnimation(.easeOut(duration: 0.6)) {
            animatedProgress = targetProgress
        }

        showActiveWalk = false
    }
    
    func generateEveningReview(coinVM: CoinViewModel, streakVM: StreakViewModel, journeyVM: JourneyViewModel) {
        guard isEveningMode && eveningReview == nil else { return }
        
        eveningReview = EveningReview.generate(
            steps: currentSteps,
            tiers: coinVM.highestTierReached,
            coins: coinVM.todayEarnings,
            streak: streakVM.streak.currentStreak,
            journeyDistance: journeyVM.todayDistanceKm,
            nextCity: journeyVM.activeJourney?.nextMilestone?.name,
            distanceRemaining: journeyVM.activeJourney?.distanceToNextMilestone,
            weeklyAvgSteps: weeklyAvgSteps
        )
    }
    
    func claimReviewCoins(coinVM: CoinViewModel) {
        guard var review = eveningReview, !review.isViewed else { return }
        review.isViewed = true
        eveningReview = review
        coinVM.earn(amount: 5, source: .dailyReview, description: "Viewed daily review")
    }

    func nextTip() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTipIndex = (currentTipIndex + 1) % healthTips.count
        }
    }

    func previousTip() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTipIndex = (currentTipIndex - 1 + healthTips.count) % healthTips.count
        }
    }
}
```

- [ ] **Step 2: Update DashboardView to use new components**

Replace `DashboardView` with:

```swift
import SwiftUI

struct DashboardView: View {
    @State private var vm = DashboardViewModel()
    @Environment(\.coinVM) private var coinVM
    @Environment(\.streakVM) private var streakVM
    @Environment(\.journeyVM) private var journeyVM

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Header with coin balance
                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.iwPrimary)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "figure.walk")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                            Text("iWalk AI")
                                .font(IWFont.titleMedium())
                                .foregroundStyle(Color.iwOnSurface)
                        }
                        Spacer()
                        StreakBadgeView(streak: streakVM.streak)
                        CoinBalanceView(balance: coinVM.account.balance)
                    }

                    // Evening Review or Daytime Progress
                    if vm.isEveningMode, let review = vm.eveningReview {
                        AnimatedCard(delay: 0.1) {
                            EveningReviewCard(review: review) {
                                vm.claimReviewCoins(coinVM: coinVM)
                                vm.showEveningDetails = true
                            }
                        }
                    } else {
                        // Tiered Progress Bar
                        AnimatedCard(delay: 0.1) {
                            TieredProgressBar(
                                currentSteps: vm.animatedSteps,
                                goalSteps: vm.stepGoal,
                                tiers: coinVM.todayTiers,
                                personalGoal: coinVM.personalGoal,
                                animatedProgress: vm.animatedProgress
                            )
                        }

                        // Start Walking Button
                        PillButton("Start Walking Now", icon: "figure.walk") {
                            vm.startWalking()
                        }
                    }

                    // Journey Card
                    if let journey = journeyVM.activeJourney {
                        AnimatedCard(delay: 0.15) {
                            JourneyCard(journey: journey)
                        }
                    }

                    // Stats Row
                    AnimatedCard(delay: 0.2) {
                        HStack(spacing: 0) {
                            StatCard(
                                icon: "flame.fill",
                                value: "\(vm.todayStats.calories)",
                                label: "kcal",
                                iconColor: .iwTertiaryContainer
                            )
                            StatCard(
                                icon: "mappin.and.ellipse",
                                value: String(format: "%.1f", vm.todayStats.distanceKm),
                                label: "km",
                                iconColor: .iwSecondary
                            )
                            StatCard(
                                icon: "clock.fill",
                                value: "\(vm.todayStats.activeMinutes)",
                                label: "mins",
                                iconColor: .iwPrimaryContainer
                            )
                        }
                        .padding(.vertical, 16)
                        .background(Color.iwSurfaceContainerLowest)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }

                    // Today's Activity
                    AnimatedCard(delay: 0.3) {
                        VStack(spacing: 16) {
                            SectionHeader("Today's Activity", trailing: "View History") {
                                vm.showHistory = true
                            }
                            ActivityBarChart(
                                data: vm.chartData,
                                labels: vm.chartLabels,
                                accentIndex: vm.todayWeekdayIndex
                            )
                            .frame(height: 100)
                        }
                    }

                    // Health Tip
                    AnimatedCard(delay: 0.4) {
                        InfoCard(backgroundColor: .iwSurfaceContainerLow) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: vm.currentTip.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.iwTertiary)
                                    .padding(8)
                                    .background(Color.iwTertiaryFixed.opacity(0.4))
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(vm.currentTip.title)
                                        .font(IWFont.labelMedium())
                                        .foregroundStyle(Color.iwOutline)
                                    Text(vm.currentTip.content)
                                        .font(IWFont.bodyMedium())
                                        .foregroundStyle(Color.iwOnSurface)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { vm.nextTip() }

                        HStack(spacing: 6) {
                            ForEach(0..<vm.healthTips.count, id: \.self) { i in
                                Circle()
                                    .fill(i == vm.currentTipIndex ? Color.iwPrimary : Color.iwOutlineVariant)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .background(Color.iwSurface)
            
            // Coin Toast overlay
            if coinVM.showCoinToast {
                CoinToast(amount: coinVM.lastEarnedAmount, source: coinVM.lastEarnedSource)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .onAppear {
            vm.animateOnAppear()
            // Check tiers for current steps
            coinVM.checkStepTiers(currentSteps: vm.currentSteps)
            // Check streak
            if vm.currentSteps >= 1500 {
                streakVM.completeTodayIfNeeded(coinVM: coinVM)
            }
            // Generate evening review if applicable
            vm.generateEveningReview(coinVM: coinVM, streakVM: streakVM, journeyVM: journeyVM)
        }
        .sheet(isPresented: $vm.showHistory) {
            HistorySheet(weeklyActivity: vm.weeklyActivity)
        }
        .fullScreenCover(isPresented: $vm.showActiveWalk) {
            ActiveWalkContainerView(
                vm: ActiveWalkViewModel(
                    dailyGoal: vm.stepGoal,
                    stepsBeforeWalk: vm.currentSteps
                ),
                onComplete: { session in
                    vm.onWalkCompleted(session: session)
                    // Award walk session coins
                    coinVM.earn(amount: 5, source: .walkSession, description: "Walk completed")
                    // Check new tiers
                    coinVM.checkStepTiers(currentSteps: session.totalSteps)
                    // Check streak
                    if session.totalSteps >= 1500 {
                        streakVM.completeTodayIfNeeded(coinVM: coinVM)
                    }
                    // Update journey
                    journeyVM.addWalkDistance(session.distanceKm, coinVM: coinVM)
                }
            )
        }
    }
}

// MARK: - History Sheet

private struct HistorySheet: View {
    let weeklyActivity: [DailyStats]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(weeklyActivity) { day in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.date.formatted(.dateTime.weekday(.wide).month().day()))
                            .font(IWFont.labelLarge())
                            .foregroundStyle(Color.iwOnSurface)
                        Text("\(day.steps.formatted()) steps")
                            .font(IWFont.bodyMedium())
                            .foregroundStyle(Color.iwOutline)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(day.calories) kcal")
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwTertiary)
                        Text(String(format: "%.1f km", day.distanceKm))
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwSecondary)
                    }
                }
                .listRowBackground(Color.iwSurfaceContainerLowest)
            }
            .scrollContentBackground(.hidden)
            .background(Color.iwSurface)
            .navigationTitle("Activity History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.iwPrimary)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify**

Run same build command. Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add "iWalk AI/Views/DashboardView.swift" "iWalk AI/ViewModels/DashboardViewModel.swift"
git commit -m "feat: integrate coin, streak, journey, evening review into Dashboard"
```

---

## Task 16: Update HabitsView — Add Freeze Cards and Real Streak

**Files:**
- Modify: `iWalk AI/Views/HabitsView.swift`
- Modify: `iWalk AI/ViewModels/HabitsViewModel.swift`

- [ ] **Step 1: Update HabitsViewModel to use StreakViewModel**

In `HabitsViewModel`, remove the hardcoded streak values and add freeze card support. Replace the `currentStreak` and `longestStreak` computed properties:

Replace lines 16-17 (`var currentStreak: Int { 7 }` and `var longestStreak: Int { 14 }`) with nothing — these will come from StreakViewModel through the view's environment.

The `HabitsViewModel` does not need direct reference to `StreakViewModel`; the view will read streak data from environment.

- [ ] **Step 2: Add freeze card section to HabitsView**

In `HabitsView`, after the "Current Progress" `AnimatedCard` (line 13-36), add freeze card info. Update the streak display to use environment StreakViewModel:

Add `@Environment(\.streakVM) private var streakVM` to `HabitsView`.

Replace the "Current Progress" section's streak text (`vm.currentStreak`) with `streakVM.streak.currentStreak`.

After the "Current Progress" card, add:

```swift
// Freeze Cards
if streakVM.streak.freezeCardsRemaining > 0 {
    AnimatedCard(delay: 0.15) {
        InfoCard(backgroundColor: .iwSurfaceContainerLowest) {
            HStack(spacing: 12) {
                Image(systemName: "snowflake")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.iwSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Freeze Cards")
                        .font(IWFont.labelMedium())
                        .foregroundStyle(Color.iwOnSurface)
                    Text("\(streakVM.streak.freezeCardsRemaining) remaining — auto-protects your streak")
                        .font(IWFont.bodySmall())
                        .foregroundStyle(Color.iwOutline)
                }
                Spacer()
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "snowflake")
                            .font(.system(size: 12))
                            .foregroundStyle(i < streakVM.streak.freezeCardsRemaining ? Color.iwSecondary : Color.iwOutlineVariant)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify**

Run same build command. Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add "iWalk AI/Views/HabitsView.swift" "iWalk AI/ViewModels/HabitsViewModel.swift"
git commit -m "feat: add freeze cards to HabitsView, wire real streak data"
```

---

## Task 17: Update BadgesView — Add Share Button and Coin Integration

**Files:**
- Modify: `iWalk AI/Views/BadgesView.swift`
- Modify: `iWalk AI/ViewModels/BadgesViewModel.swift`
- Modify: `iWalk AI/Models/WalkModels.swift`

- [ ] **Step 1: Add LeaderboardSyncSource to WalkModels.swift**

Add at the end of `WalkModels.swift`:

```swift
// MARK: - Leaderboard Sync

enum LeaderboardSyncSource {
    case local
    case cloudKit
}
```

- [ ] **Step 2: Add share button to BadgeDetailSheet**

In the `BadgeDetailSheet` in `BadgesView.swift`, add a share button before the "Done" button. Add a `@State private var shareImage: UIImage?` and `@State private var showShareSheet = false`.

After the requirement InfoCard and before `Spacer()`, add:

```swift
// Share button
if badge.isUnlocked {
    ShareLink(
        item: Image(uiImage: ShareCardRenderer.renderImage(
            stats: .badgeUnlock(badgeName: badge.name)
        ) ?? UIImage()),
        preview: SharePreview("Badge: \(badge.name)", image: Image(systemName: badge.icon))
    ) {
        HStack(spacing: 6) {
            Image(systemName: "square.and.arrow.up")
            Text("Share Achievement")
        }
        .font(IWFont.labelLarge())
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.iwPrimaryGradient)
        .clipShape(Capsule())
    }
}
```

- [ ] **Step 3: Build to verify**

Run same build command. Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add "iWalk AI/Views/BadgesView.swift" "iWalk AI/ViewModels/BadgesViewModel.swift" "iWalk AI/Models/WalkModels.swift"
git commit -m "feat: add share button to badges, add LeaderboardSyncSource"
```

---

## Task 18: Update CoachViewModel — Streak-Aware Messages

**Files:**
- Modify: `iWalk AI/ViewModels/CoachViewModel.swift`
- Modify: `iWalk AI/Views/AICoachView.swift`

- [ ] **Step 1: Add streak awareness to CoachViewModel**

Add a method to `CoachViewModel`:

```swift
func generateStreakMessage(streak: StreakData) -> String? {
    if streak.isAtRisk {
        return "Hey \(user.name)! You still need \(max(1500 - 0, 1500)) steps to keep your \(streak.currentStreak)-day streak alive. A quick 15-minute walk should do it!"
    }
    if StreakData.milestones.contains(streak.currentStreak) && streak.isActiveToday {
        return "Amazing! You've hit a \(streak.currentStreak)-day streak! That's real dedication. Your consistency is building lasting health habits."
    }
    if streak.currentStreak == 1 && streak.longestStreak > 1 {
        return "Welcome back! Every streak starts with day one. You've done \(streak.longestStreak) days before — you can do it again!"
    }
    return nil
}
```

Also update `todaysFocus` to be a method that takes streak data:

```swift
func todaysFocus(streak: StreakData) -> String {
    if streak.isActiveToday {
        return "Great job reaching your minimum today! Keep walking to reach higher tiers."
    }
    return "Reach 1,500 steps to maintain your \(streak.currentStreak)-day streak."
}
```

- [ ] **Step 2: Update AICoachView to show streak messages**

Add `@Environment(\.streakVM) private var streakVM` to `AICoachView`.

In the view body, add a streak-aware message card if applicable (before the recommendations section). Read the current `AICoachView.swift` first to determine the exact insertion point.

- [ ] **Step 3: Build to verify**

Run same build command. Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add "iWalk AI/ViewModels/CoachViewModel.swift" "iWalk AI/Views/AICoachView.swift"
git commit -m "feat: add streak-aware AI coach messages"
```

---

## Task 19: Journey Detail View with MapKit

**Files:**
- Create: `iWalk AI/Views/JourneyDetailView.swift`

- [ ] **Step 1: Create JourneyDetailView.swift**

```swift
// iWalk AI/Views/JourneyDetailView.swift
import SwiftUI
import MapKit

struct JourneyDetailView: View {
    let journey: VirtualJourney
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Map
                    mapSection
                    
                    // Progress summary
                    progressSection
                    
                    // Milestones list
                    milestonesSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color.iwSurface)
            .navigationTitle(journey.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.iwPrimary)
                }
            }
        }
    }
    
    private var mapSection: some View {
        Map {
            // Route line through milestones
            MapPolyline(coordinates: journey.milestones.map(\.coordinate.clLocation))
                .stroke(.iwSecondary, lineWidth: 3)
            
            // Milestone markers
            ForEach(journey.milestones) { milestone in
                Annotation(milestone.name, coordinate: milestone.coordinate.clLocation) {
                    Circle()
                        .fill(milestone.isReached ? Color.iwPrimary : Color.iwSurfaceContainerHigh)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Image(systemName: milestone.isReached ? "checkmark" : "")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }
            }
            
            // Current position
            if let current = currentPosition {
                Annotation("You", coordinate: current) {
                    Image(systemName: "figure.walk.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.iwPrimary)
                        .background(Circle().fill(.white).frame(width: 20, height: 20))
                }
            }
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var currentPosition: CLLocationCoordinate2D? {
        let milestones = journey.milestones.sorted { $0.distanceFromStartKm < $1.distanceFromStartKm }
        
        // Find which segment we're on
        var prev: JourneyMilestone?
        for m in milestones {
            if journey.distanceCoveredKm < m.distanceFromStartKm {
                if let p = prev {
                    let segDist = m.distanceFromStartKm - p.distanceFromStartKm
                    let progress = (journey.distanceCoveredKm - p.distanceFromStartKm) / segDist
                    let lat = p.coordinate.latitude + (m.coordinate.latitude - p.coordinate.latitude) * progress
                    let lon = p.coordinate.longitude + (m.coordinate.longitude - p.coordinate.longitude) * progress
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                } else {
                    return milestones.first?.coordinate.clLocation
                }
            }
            prev = m
        }
        return milestones.last?.coordinate.clLocation
    }
    
    private var progressSection: some View {
        InfoCard(backgroundColor: .iwSurfaceContainerLowest) {
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(String(format: "%.0f", journey.distanceCoveredKm))
                        .font(IWFont.titleLarge())
                        .foregroundStyle(Color.iwOnSurface)
                    Text("km walked")
                        .font(IWFont.labelSmall())
                        .foregroundStyle(Color.iwOutline)
                }
                VStack(spacing: 4) {
                    Text("\(Int(journey.progress * 100))%")
                        .font(IWFont.titleLarge())
                        .foregroundStyle(Color.iwPrimary)
                    Text("complete")
                        .font(IWFont.labelSmall())
                        .foregroundStyle(Color.iwOutline)
                }
                VStack(spacing: 4) {
                    Text("\(journey.reachedMilestones.count)/\(journey.milestones.count)")
                        .font(IWFont.titleLarge())
                        .foregroundStyle(Color.iwOnSurface)
                    Text("cities")
                        .font(IWFont.labelSmall())
                        .foregroundStyle(Color.iwOutline)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var milestonesSection: some View {
        VStack(spacing: 12) {
            SectionHeader("Milestones")
            
            ForEach(journey.milestones) { milestone in
                InfoCard(backgroundColor: .iwSurfaceContainerLowest) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(milestone.isReached ? Color.iwPrimary.opacity(0.15) : Color.iwSurfaceContainerHigh)
                                .frame(width: 44, height: 44)
                            Image(systemName: milestone.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(milestone.isReached ? Color.iwPrimary : Color.iwOutline)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(milestone.name)
                                    .font(IWFont.labelLarge())
                                    .foregroundStyle(Color.iwOnSurface)
                                Spacer()
                                Text(String(format: "%.0f km", milestone.distanceFromStartKm))
                                    .font(IWFont.labelSmall())
                                    .foregroundStyle(Color.iwOutline)
                            }
                            
                            if milestone.isReached {
                                Text(milestone.funFact)
                                    .font(IWFont.bodySmall())
                                    .foregroundStyle(Color.iwOutline)
                                    .lineSpacing(2)
                                if let date = milestone.reachedDate {
                                    Text("Reached \(date.formatted(.dateTime.month().day()))")
                                        .font(IWFont.labelSmall())
                                        .foregroundStyle(Color.iwPrimary)
                                }
                            } else {
                                let remaining = max(milestone.distanceFromStartKm - journey.distanceCoveredKm, 0)
                                Text(String(format: "%.0f km remaining", remaining))
                                    .font(IWFont.bodySmall())
                                    .foregroundStyle(Color.iwOutlineVariant)
                            }
                        }
                    }
                }
                .opacity(milestone.isReached ? 1.0 : 0.7)
            }
        }
    }
}
```

- [ ] **Step 2: Make JourneyCard tappable — navigate to detail**

In `DashboardView.swift`, wrap the `JourneyCard` in a `NavigationLink` or add a sheet:

```swift
// Replace the JourneyCard AnimatedCard with:
if let journey = journeyVM.activeJourney {
    AnimatedCard(delay: 0.15) {
        JourneyCard(journey: journey)
            .contentShape(Rectangle())
            .onTapGesture { vm.showJourneyDetail = true }
    }
}
```

Add `var showJourneyDetail = false` to `DashboardViewModel`.

Add a `.sheet` to `DashboardView`:

```swift
.sheet(isPresented: $vm.showJourneyDetail) {
    if let journey = journeyVM.activeJourney {
        JourneyDetailView(journey: journey)
    }
}
```

- [ ] **Step 3: Build to verify**

Run same build command. Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add "iWalk AI/Views/JourneyDetailView.swift" "iWalk AI/Views/DashboardView.swift" "iWalk AI/ViewModels/DashboardViewModel.swift"
git commit -m "feat: add journey detail view with MapKit and milestone list"
```

---

## Task 20: Final Build Verification and Clean Up

- [ ] **Step 1: Full build**

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && export PATH="$DEVELOPER_DIR/usr/bin:$PATH" && xcodebuild build -project "iWalk AI.xcodeproj" -scheme "iWalk AI" -destination "platform=iOS Simulator,name=iPhone 17 Pro" 2>&1 | xcbeautify --quiet
```

Expected: BUILD SUCCEEDED

- [ ] **Step 2: Fix any compile errors**

If errors exist, read the full error output and fix all issues in one pass.

- [ ] **Step 3: Run on simulator to verify UI**

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && export PATH="$DEVELOPER_DIR/usr/bin:$PATH"
UDID=$(xcrun simctl list devices | grep "iPhone 17 Pro" | grep -v "Plus\|Max" | head -1 | grep -oE "[A-F0-9-]{36}")
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -path "*/iWalk_AI*/Build/Products/Debug-iphonesimulator/iWalk AI.app" -maxdepth 5 | head -1)
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl launch --terminate-running-process "$UDID" "kanshaous.iWalk-AI"
```

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete WeWard-inspired gamification feature pack

Adds coin engine, multi-tier daily goals, streak system with freeze cards,
virtual journey with US city routes, evening review, and share cards."
```

---

## Verification Checklist

- [ ] All 19 new files created and compiling
- [ ] Coin balance shows in Dashboard header
- [ ] Tiered progress bar replaces old progress view
- [ ] Streak badge visible in Dashboard header
- [ ] Journey card shows in Dashboard
- [ ] Evening review card appears after 8 PM
- [ ] Coin toast appears on tier reach
- [ ] Journey detail view shows MapKit route
- [ ] Share button works on badge detail
- [ ] Freeze cards visible in HabitsView
- [ ] AI Coach shows streak-aware messages
- [ ] No force-unwraps or hardcoded secrets
- [ ] No new warnings introduced
