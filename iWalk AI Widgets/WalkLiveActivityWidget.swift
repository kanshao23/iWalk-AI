import ActivityKit
import WidgetKit
import SwiftUI

struct WalkLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkActivityAttributes.self) { context in
            WalkLockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.9))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Steps", systemImage: "figure.walk")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.state.totalSteps.formatted())
                            .font(.headline)
                            .monospacedDigit()
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Distance")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f km", context.state.distanceKm))
                            .font(.headline)
                            .monospacedDigit()
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.isPaused ? "pause.fill" : "clock.fill")
                            .font(.caption)
                            .foregroundStyle(context.state.isPaused ? .yellow : .green)
                        if context.state.isPaused {
                            Text(elapsedText(context.state.elapsedSeconds))
                                .font(.headline)
                                .monospacedDigit()
                        } else {
                            Text(context.state.startAdjustedDate, style: .timer)
                                .font(.headline)
                                .monospacedDigit()
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    let progress = progressValue(
                        steps: context.state.totalSteps,
                        goal: context.attributes.dailyGoal
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: progress)
                            .tint(.green)
                        Text("Goal \(Int(progress * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Text(shortStepText(context.state.totalSteps))
                    .font(.caption2)
                    .monospacedDigit()
            } compactTrailing: {
                Text(elapsedText(context.state.elapsedSeconds))
                    .font(.caption2)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "figure.walk.circle.fill")
            }
            .widgetURL(URL(string: "iwalkai://active-walk"))
            .keylineTint(.green)
        }
    }

    private func progressValue(steps: Int, goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(Double(steps) / Double(goal), 1.0)
    }

    private func elapsedText(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func shortStepText(_ steps: Int) -> String {
        if steps >= 1_000 {
            let value = Double(steps) / 1_000.0
            return String(format: "%.1fk", value)
        }
        return "\(steps)"
    }
}

private struct WalkLockScreenView: View {
    let context: ActivityViewContext<WalkActivityAttributes>

    var body: some View {
        let progress = max(
            0,
            min(Double(context.state.totalSteps) / Double(max(context.attributes.dailyGoal, 1)), 1)
        )

        VStack(alignment: .leading, spacing: 8) {
            // Title row
            HStack(spacing: 8) {
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "figure.walk")
                    .foregroundStyle(context.state.isPaused ? .yellow : .green)
                Text(context.state.isPaused ? "Walk paused" : "Walk in progress")
                    .font(.headline)
                Spacer()
            }

            // Metrics
            HStack(spacing: 0) {
                metricBlock(title: "Steps",    value: context.state.totalSteps.formatted())
                metricBlock(title: "Distance", value: String(format: "%.2f km", context.state.distanceKm))
                // Time: auto-ticking timer when active, frozen text when paused
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if context.state.isPaused {
                        Text(elapsedText(context.state.elapsedSeconds))
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                    } else {
                        Text(context.state.startAdjustedDate, style: .timer)
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Progress
            ProgressView(value: progress)
                .tint(.green)
            HStack(spacing: 4) {
                let remaining = max(0, context.attributes.dailyGoal - context.state.totalSteps)
                Text("Goal \(context.state.totalSteps.formatted()) / \(context.attributes.dailyGoal.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if remaining > 0 {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(remaining.formatted()) steps to go")
                        .font(.caption)
                        .foregroundStyle(.green.opacity(0.85))
                } else {
                    Text("· Goal reached!")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            // Action buttons
            HStack(spacing: 10) {
                Link(destination: URL(string: "iwalkai://pause-walk")!) {
                    Label(
                        context.state.isPaused ? "Resume" : "Pause",
                        systemImage: context.state.isPaused ? "play.fill" : "pause.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(context.state.isPaused ? .green : .white.opacity(0.85))
                    .clipShape(Capsule())
                }

                Link(destination: URL(string: "iwalkai://end-walk")!) {
                    Label("End", systemImage: "stop.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(.red.opacity(0.8))
                        .clipShape(Capsule())
                }

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func metricBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func elapsedText(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
