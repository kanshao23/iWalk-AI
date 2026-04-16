import Foundation
import ActivityKit

struct WalkActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Steps walked in this session only (starts from 0 each walk).
        var sessionSteps: Int
        /// Total daily steps including steps before this walk (used for goal progress).
        var totalSteps: Int
        var distanceKm: Double
        /// Used as reference date for `Text(.timer)` in the widget when active.
        /// Formula: walkStartDate + totalPausedDuration
        /// When paused, this is frozen at the moment of pause so timer won't tick.
        var startAdjustedDate: Date
        /// Elapsed seconds at pause time, for static display when paused.
        var elapsedSeconds: Int
        var isPaused: Bool
    }

    var dailyGoal: Int
}
