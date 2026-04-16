import Foundation
import ActivityKit
import os

@MainActor
final class WalkLiveActivityManager {
    static let shared = WalkLiveActivityManager()

    private var activity: Activity<WalkActivityAttributes>?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "kanshaous.iWalk-AI", category: "WalkLiveActivity")

    private init() {}

    /// True when a walk Live Activity is currently running (either in this session or an orphaned one).
    var isActive: Bool {
        guard #available(iOS 16.2, *) else { return false }
        return activity != nil || !Activity<WalkActivityAttributes>.activities.isEmpty
    }

    func start(dailyGoal: Int, totalSteps: Int, distanceKm: Double,
               startAdjustedDate: Date, elapsedSeconds: Int) {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.debug("Live Activity disabled in system settings.")
            return
        }

        let attributes = WalkActivityAttributes(dailyGoal: dailyGoal)
        let state = WalkActivityAttributes.ContentState(
            totalSteps: totalSteps,
            distanceKm: distanceKm,
            startAdjustedDate: startAdjustedDate,
            elapsedSeconds: elapsedSeconds,
            isPaused: false
        )

        if let existing = activity ?? Activity<WalkActivityAttributes>.activities.first {
            activity = existing
            update(totalSteps: totalSteps, distanceKm: distanceKm,
                   startAdjustedDate: startAdjustedDate, elapsedSeconds: elapsedSeconds,
                   isPaused: false)
            return
        }

        do {
            let content = ActivityContent(state: state, staleDate: nil)
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            logger.error("Failed to start Live Activity: \(String(describing: error), privacy: .public)")
        }
    }

    func update(totalSteps: Int, distanceKm: Double,
                startAdjustedDate: Date, elapsedSeconds: Int, isPaused: Bool) {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = activity ?? Activity<WalkActivityAttributes>.activities.first else { return }
        self.activity = activity

        let state = WalkActivityAttributes.ContentState(
            totalSteps: totalSteps,
            distanceKm: distanceKm,
            startAdjustedDate: startAdjustedDate,
            elapsedSeconds: elapsedSeconds,
            isPaused: isPaused
        )
        let content = ActivityContent(state: state, staleDate: nil)
        Task { await activity.update(content) }
    }

    func end(totalSteps: Int, distanceKm: Double,
             startAdjustedDate: Date, elapsedSeconds: Int) {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = activity ?? Activity<WalkActivityAttributes>.activities.first else { return }

        let finalState = WalkActivityAttributes.ContentState(
            totalSteps: totalSteps,
            distanceKm: distanceKm,
            startAdjustedDate: startAdjustedDate,
            elapsedSeconds: elapsedSeconds,
            isPaused: false
        )
        let content = ActivityContent(state: finalState, staleDate: nil)
        Task { await activity.end(content, dismissalPolicy: .immediate) }
        self.activity = nil
    }
}
