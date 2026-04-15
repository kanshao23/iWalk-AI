import WidgetKit
import SwiftUI
import HealthKit

// MARK: - Data Model

struct WalkDailyEntry: TimelineEntry {
    let date: Date
    let steps: Int
    let distanceKm: Double
    let calories: Int
    let dailyGoal: Int

    var progress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(Double(steps) / Double(dailyGoal), 1.0)
    }

    static let placeholder = WalkDailyEntry(
        date: .now, steps: 4823, distanceKm: 3.6, calories: 241, dailyGoal: 10000
    )
}

// MARK: - Timeline Provider

struct WalkSummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> WalkDailyEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (WalkDailyEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WalkDailyEntry>) -> Void) {
        Task {
            let steps    = await WidgetHealthKit.fetchSteps()
            let distance = await WidgetHealthKit.fetchDistance()
            let calories = await WidgetHealthKit.fetchCalories()

            let entry = WalkDailyEntry(
                date: .now,
                steps: steps,
                distanceKm: distance,
                calories: calories,
                dailyGoal: 10000
            )
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }
}

// MARK: - Lightweight HealthKit (widget-local, no heavy imports)

private enum WidgetHealthKit {
    static func fetchSteps() async -> Int {
        Int(await fetch(.stepCount, unit: .count()))
    }

    static func fetchDistance() async -> Double {
        await fetch(.distanceWalkingRunning, unit: .meterUnit(with: .kilo))
    }

    static func fetchCalories() async -> Int {
        Int(await fetch(.activeEnergyBurned, unit: .kilocalorie()))
    }

    private static func fetch(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        let store = HKHealthStore()
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKQuantityType.quantityType(forIdentifier: id)
        else { return 0 }

        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: .now, options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            store.execute(HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            })
        }
    }
}

// MARK: - Widget Configuration

struct WalkSummaryWidget: Widget {
    let kind = "WalkSummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WalkSummaryProvider()) { entry in
            WalkSummaryWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Steps")
        .description("Today's steps and quick access to start a walk.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Root

private struct WalkSummaryWidgetView: View {
    let entry: WalkDailyEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall: SmallWalkWidget(entry: entry)
        default:           MediumWalkWidget(entry: entry)
        }
    }
}

// MARK: - Small Widget (2×2)

private struct SmallWalkWidget: View {
    let entry: WalkDailyEntry

    var body: some View {
        ZStack {
            WidgetBackground()
            VStack(alignment: .leading, spacing: 0) {
                Label("Today", systemImage: "figure.walk")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.steps.formatted())
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("steps")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                ProgressCapsule(progress: entry.progress, height: 5)

                Spacer().frame(height: 5)

                Text("\(Int(entry.progress * 100))% of \(entry.dailyGoal.formatted()) goal")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .widgetURL(URL(string: "iwalkai://active-walk"))
        .containerBackground(for: .widget) { Color(widgetHex: "0F1923") }
    }
}

// MARK: - Medium Widget (4×2)

private struct MediumWalkWidget: View {
    let entry: WalkDailyEntry

    var body: some View {
        ZStack {
            WidgetBackground()
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    Label("Today's Walk", systemImage: "figure.walk")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                    Spacer()
                    Text(entry.date, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.35))
                }

                // Three metrics
                HStack(spacing: 0) {
                    MetricBlock(
                        value: entry.steps.formatted(),
                        label: "steps",
                        icon: "figure.walk"
                    )
                    WidgetDivider()
                    MetricBlock(
                        value: String(format: "%.1f", entry.distanceKm),
                        label: "km",
                        icon: "mappin.and.ellipse"
                    )
                    WidgetDivider()
                    MetricBlock(
                        value: "\(entry.calories)",
                        label: "kcal",
                        icon: "flame.fill"
                    )
                }

                // Progress + CTA
                VStack(alignment: .leading, spacing: 6) {
                    ProgressCapsule(progress: entry.progress, height: 6)
                    HStack {
                        Text("\(entry.steps.formatted()) / \(entry.dailyGoal.formatted()) steps")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                        Spacer()
                        Link(destination: URL(string: "iwalkai://active-walk")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Start Walking")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.green)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .containerBackground(for: .widget) { Color(widgetHex: "0F1923") }
    }
}

// MARK: - Shared Sub-views

private struct ProgressCapsule: View {
    let progress: Double
    let height: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.15))
                    .frame(height: height)
                Capsule()
                    .fill(LinearGradient(
                        colors: [.green.opacity(0.7), .green],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geo.size.width * max(0, min(progress, 1.0)), height: height)
            }
        }
        .frame(height: height)
    }
}

private struct MetricBlock: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.green.opacity(0.85))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WidgetDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(width: 1, height: 38)
    }
}

private struct WidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(widgetHex: "0F1923"), Color(widgetHex: "162032")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Color hex (widget-local, avoids cross-target design system dep)

private extension Color {
    init(widgetHex hex: String) {
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
