import SwiftUI
import CoreMotion
import CoreLocation

@Observable
final class ActiveWalkViewModel {
    // Phase state machine
    var phase: WalkPhase = .countdown(3)

    // Live stats
    var elapsedSeconds: Int = 0
    var sessionSteps: Int = 0
    var sessionCalories: Int = 0
    var sessionDistanceKm: Double = 0.0
    var currentHeartRate: Int = 0
    var hasRealHeartRate: Bool = false

    // Milestone toast
    var showMilestoneToast = false
    var currentMilestone: WalkMilestone?
    private var shownMilestones: Set<String> = []
    var routePoints: [WalkRoutePoint] = []

    // Config
    let dailyGoal: Int
    let stepsBeforeWalk: Int
    private let startTime = Date()

    // Pedometer
    private let pedometer = CMPedometer()
    private(set) var usesRealPedometer = false

    // Timers
    private var countdownTimer: Timer?
    private var simulationTimer: Timer? // Only used when pedometer unavailable
    private var elapsedTimer: Timer?
    private var heartRateTimer: Timer?
    private var liveActivityTick = 0

    // Wall-clock elapsed tracking (survives screen lock)
    private var walkStartDate: Date?
    private var pausedDuration: TimeInterval = 0
    private var pauseStartDate: Date?

    /// Date for `Text(.timer)` in Live Activity: walkStartDate + pausedDuration
    /// so `now - walkAdjustedStartDate == elapsedSeconds` at any moment.
    private var walkAdjustedStartDate: Date {
        (walkStartDate ?? Date()).addingTimeInterval(pausedDuration)
    }

    // NotificationCenter observer tokens
    private var observers: [NSObjectProtocol] = []

    // Computed
    var totalSteps: Int { stepsBeforeWalk + sessionSteps }
    var goalProgress: Double { min(Double(totalSteps) / Double(dailyGoal), 1.0) }

    var paceMinPerKm: Double {
        guard sessionDistanceKm > 0.01 else { return 0 }
        return (Double(elapsedSeconds) / 60.0) / sessionDistanceKm
    }

    var paceFormatted: String {
        guard paceMinPerKm > 0 && paceMinPerKm < 100 else { return "--:--" }
        let mins = Int(paceMinPerKm)
        let secs = Int((paceMinPerKm - Double(mins)) * 60)
        return String(format: "%d:%02d", mins, secs)
    }

    var elapsedFormatted: String {
        let mins = elapsedSeconds / 60
        let secs = elapsedSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var heartRateZone: String {
        switch currentHeartRate {
        case ..<100: "Warm Up"
        case 100..<120: "Fat Burn"
        case 120..<140: "Cardio"
        default: "Peak"
        }
    }

    var heartRateZoneColor: Color {
        switch currentHeartRate {
        case ..<100: .iwPrimaryContainer
        case 100..<120: .iwPrimary
        case 120..<140: .iwTertiary
        default: .iwError
        }
    }

    var gradientProgress: Double { min(goalProgress, 1.0) }
    var isActive: Bool { phase == .active }
    var isPaused: Bool { phase == .paused }
    var dataSource: String { usesRealPedometer ? "Pedometer" : "Simulated" }

    init(dailyGoal: Int, stepsBeforeWalk: Int) {
        self.dailyGoal = dailyGoal
        self.stepsBeforeWalk = stepsBeforeWalk
    }

    deinit {
        invalidateAll()
    }

    // MARK: - Countdown

    func startCountdown() {
        var count = 3
        phase = .countdown(count)

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            count -= 1
            if count > 0 {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    self.phase = .countdown(count)
                }
            } else if count == 0 {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    self.phase = .countdown(0)
                }
            } else {
                timer.invalidate()
                self.countdownTimer = nil
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.phase = .active
                }
                self.beginWalking()
            }
        }
    }

    // MARK: - Walking

    private func beginWalking() {
        walkStartDate = Date()
        startElapsedTimer()
        startHeartRatePolling()
        registerURLObservers()

        Task { @MainActor in
            WalkLiveActivityManager.shared.start(
                dailyGoal: dailyGoal,
                totalSteps: totalSteps,
                distanceKm: sessionDistanceKm,
                startAdjustedDate: walkAdjustedStartDate,
                elapsedSeconds: elapsedSeconds
            )
        }
        pushLiveActivityUpdate(force: true)

        // Try real pedometer first
        if CMPedometer.isStepCountingAvailable() {
            usesRealPedometer = true
            startRealPedometer()
        } else {
            usesRealPedometer = false
            startSimulation()
        }
    }

    private func startRealPedometer() {
        pedometer.startUpdates(from: startTime) { [weak self] data, error in
            guard let self, let data, error == nil else { return }
            DispatchQueue.main.async {
                self.sessionSteps = data.numberOfSteps.intValue
                if let distance = data.distance {
                    self.sessionDistanceKm = distance.doubleValue / 1000.0
                } else {
                    // Pedometer doesn't provide distance on this device; estimate from steps
                    self.sessionDistanceKm = Double(self.sessionSteps) / 1350.0
                }
                // Calories: ~0.04 kcal per step (walking average)
                self.sessionCalories = Int(Double(self.sessionSteps) * 0.04)
                self.checkMilestones()
                // Always push on real step data — pedometer is infrequent and
                // continues in background, so we want every update reflected immediately.
                self.pushLiveActivityUpdate(force: true)
            }
        }
    }

    private func startSimulation() {
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let increment = Int.random(in: 10...28)
            self.sessionSteps += increment
            self.sessionCalories = Int(Double(self.sessionSteps) * 0.04)
            self.sessionDistanceKm = Double(self.sessionSteps) / 1350.0
            self.checkMilestones()
            self.pushLiveActivityUpdate()
        }
    }

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            // Only update in-app elapsed display. Live Activity time is handled by
            // Text(.timer) which auto-ticks without app pushes.
            self.recalculateElapsed()
        }
        // Catch up after screen lock / foreground return
        let fgToken = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.recalculateElapsed()
        }
        observers.append(fgToken)
    }

    private func recalculateElapsed() {
        guard let start = walkStartDate else { return }
        elapsedSeconds = max(0, Int(Date().timeIntervalSince(start) - pausedDuration))
    }

    private func startHeartRatePolling() {
        // Poll HealthKit for latest heart rate (requires Apple Watch)
        heartRateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            Task {
                if let hr = await HealthKitManager.shared.fetchLatestHeartRate() {
                    await MainActor.run {
                        self.currentHeartRate = hr
                        self.hasRealHeartRate = true
                    }
                }
            }
        }
        // Initial fetch
        Task {
            if let hr = await HealthKitManager.shared.fetchLatestHeartRate() {
                await MainActor.run {
                    currentHeartRate = hr
                    hasRealHeartRate = true
                }
            }
        }
    }

    func pause() {
        guard phase == .active else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .paused
        }
        pauseStartDate = Date()
        if usesRealPedometer {
            pedometer.stopUpdates()
        }
        simulationTimer?.invalidate()
        simulationTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        pushLiveActivityUpdate(force: true)
    }

    func resume() {
        guard phase == .paused else { return }
        // Accumulate pause duration so elapsed stays accurate
        if let pauseStart = pauseStartDate {
            pausedDuration += Date().timeIntervalSince(pauseStart)
            pauseStartDate = nil
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .active
        }
        startElapsedTimer()
        if usesRealPedometer {
            startRealPedometer()
        } else {
            startSimulation()
        }
        pushLiveActivityUpdate(force: true)
    }

    func endWalk() {
        Task { @MainActor in
            WalkLiveActivityManager.shared.end(
                totalSteps: totalSteps,
                distanceKm: sessionDistanceKm,
                startAdjustedDate: walkAdjustedStartDate,
                elapsedSeconds: elapsedSeconds
            )
        }
        invalidateAll()
        let session = WalkSession(
            startTime: startTime,
            endTime: .now,
            steps: sessionSteps,
            calories: sessionCalories,
            distanceKm: sessionDistanceKm,
            elapsedSeconds: elapsedSeconds,
            dailyGoal: dailyGoal,
            stepsBeforeWalk: stepsBeforeWalk,
            averageHeartRate: currentHeartRate,
            routePoints: routePoints.isEmpty ? nil : routePoints
        )
        ActiveWalkViewModel.saveSession(session)
        withAnimation(.easeInOut(duration: 0.4)) {
            phase = .summary(session)
        }
    }

    // MARK: - Milestones

    private func checkMilestones() {
        for milestone in WalkMilestone.allCases {
            let key = milestone.title
            if goalProgress >= milestone.threshold && !shownMilestones.contains(key) {
                shownMilestones.insert(key)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    currentMilestone = milestone
                    showMilestoneToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                    withAnimation(.easeOut(duration: 0.3)) {
                        self?.showMilestoneToast = false
                    }
                }
            }
        }
    }

    private func registerURLObservers() {
        let pauseToken = NotificationCenter.default.addObserver(
            forName: .iwPauseResumeWalk, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if self.isPaused { self.resume() } else { self.pause() }
        }
        let endToken = NotificationCenter.default.addObserver(
            forName: .iwEndWalk, object: nil, queue: .main
        ) { [weak self] _ in
            self?.endWalk()
        }
        observers.append(contentsOf: [pauseToken, endToken])
    }

    private func invalidateAll() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        simulationTimer?.invalidate()
        simulationTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        heartRateTimer?.invalidate()
        heartRateTimer = nil
        if usesRealPedometer {
            pedometer.stopUpdates()
        }
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    private func pushLiveActivityUpdate(force: Bool = false) {
        liveActivityTick += 1
        guard force || liveActivityTick % 5 == 0 else { return }

        let paused = phase == .paused
        let total = totalSteps
        let distance = sessionDistanceKm
        let elapsed = elapsedSeconds
        let adjustedDate = walkAdjustedStartDate

        Task { @MainActor in
            WalkLiveActivityManager.shared.update(
                totalSteps: total,
                distanceKm: distance,
                startAdjustedDate: adjustedDate,
                elapsedSeconds: elapsed,
                isPaused: paused
            )
        }
    }

    func updateRouteCoordinates(_ coordinates: [CLLocationCoordinate2D]) {
        if coordinates.count < routePoints.count {
            routePoints.removeAll(keepingCapacity: true)
        }

        guard coordinates.count > routePoints.count else { return }

        for coordinate in coordinates.suffix(from: routePoints.count) {
            routePoints.append(
                WalkRoutePoint(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    timestamp: .now
                )
            )
        }
    }

    // MARK: - History Persistence

    private static let historyKey = "iw_walk_history"

    static func saveSession(_ session: WalkSession) {
        var history = loadHistory()
        history.insert(session, at: 0)
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
}

// MARK: - Notification Names (URL scheme → walk control)

extension Notification.Name {
    static let iwPauseResumeWalk = Notification.Name("iw.pauseResumeWalk")
    static let iwEndWalk = Notification.Name("iw.endWalk")
}
