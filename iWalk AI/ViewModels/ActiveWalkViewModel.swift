import SwiftUI
import CoreMotion

@Observable
final class ActiveWalkViewModel {
    // Phase state machine
    var phase: WalkPhase = .countdown(3)

    // Live stats
    var elapsedSeconds: Int = 0
    var sessionSteps: Int = 0
    var sessionCalories: Int = 0
    var sessionDistanceKm: Double = 0.0
    var currentHeartRate: Int = 85

    // Milestone toast
    var showMilestoneToast = false
    var currentMilestone: WalkMilestone?
    private var shownMilestones: Set<String> = []

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
        startElapsedTimer()
        startHeartRateSimulation()

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
                }
                // Calories: ~0.04 kcal per step (walking average)
                self.sessionCalories = Int(Double(self.sessionSteps) * 0.04)
                self.checkMilestones()
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
        }
    }

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.elapsedSeconds += 1
        }
    }

    private func startHeartRateSimulation() {
        // Heart rate simulation (real HR requires Apple Watch + HealthKit)
        heartRateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let target = self.isActive ? 120 : 95
            let drift = Int.random(in: -4...4)
            let newHR = self.currentHeartRate + (target > self.currentHeartRate ? Int.random(in: 1...3) : Int.random(in: -2...1)) + drift
            self.currentHeartRate = max(70, min(160, newHR))
        }
    }

    func pause() {
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .paused
        }
        if usesRealPedometer {
            pedometer.stopUpdates()
        }
        simulationTimer?.invalidate()
        simulationTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    func resume() {
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .active
        }
        startElapsedTimer()
        if usesRealPedometer {
            startRealPedometer()
        } else {
            startSimulation()
        }
    }

    func endWalk() {
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
            averageHeartRate: currentHeartRate
        )
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
    }
}
