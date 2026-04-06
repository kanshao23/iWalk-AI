import SwiftUI

// MARK: - Walking Path Progress

struct WalkingPathProgress: View {
    let currentSteps: Int
    let goalSteps: Int
    var animatedProgress: Double?

    private var progress: Double {
        animatedProgress ?? min(Double(currentSteps) / Double(goalSteps), 1.0)
    }

    private var percentage: Int {
        Int(progress * 100)
    }

    // Milestone markers at 25%, 50%, 75%
    private let milestones: [Double] = [0.25, 0.5, 0.75]

    /// Expected progress based on time of day (7:00–23:00 waking hours)
    private var expectedProgress: Double {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let minutesSince7am = (hour - 7) * 60 + minute
        let wakingMinutes = 16 * 60 // 7:00–23:00
        return min(max(Double(minutesSince7am) / Double(wakingMinutes), 0), 1.0)
    }

    private var isAheadOfSchedule: Bool {
        progress >= expectedProgress
    }

    var body: some View {
        VStack(spacing: 16) {
            // Walking path with walker above track
            GeometryReader { geo in
                let pathWidth = geo.size.width
                let trackY: CGFloat = 70
                let trackStart: CGFloat = 20
                let trackEnd: CGFloat = pathWidth - 20
                let trackLength = trackEnd - trackStart
                let walkerX = trackStart + trackLength * progress
                let expectedX = trackStart + trackLength * expectedProgress

                ZStack(alignment: .leading) {
                    // --- Track layer ---

                    // Background track (dashed)
                    Path { path in
                        path.move(to: CGPoint(x: trackStart, y: trackY))
                        path.addLine(to: CGPoint(x: trackEnd, y: trackY))
                    }
                    .stroke(
                        Color.iwSurfaceContainerHigh,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [8, 6])
                    )

                    // Walked track (solid gradient)
                    if progress > 0.01 {
                        Path { path in
                            path.move(to: CGPoint(x: trackStart, y: trackY))
                            path.addLine(to: CGPoint(x: trackStart + trackLength * progress, y: trackY))
                        }
                        .stroke(
                            LinearGradient(
                                colors: [.iwPrimaryContainer, .iwPrimary],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                    }

                    // Start marker
                    Circle()
                        .fill(Color.iwPrimary)
                        .frame(width: 10, height: 10)
                        .position(x: trackStart, y: trackY)

                    // --- Time-based expected position ---
                    // Dashed vertical line from track upward
                    Path { path in
                        path.move(to: CGPoint(x: expectedX, y: trackY - 7))
                        path.addLine(to: CGPoint(x: expectedX, y: trackY - 22))
                    }
                    .stroke(
                        Color.iwTertiary.opacity(0.5),
                        style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                    )

                    // "Now" label below track
                    Text("Now")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.iwTertiary)
                        .position(x: expectedX, y: trackY + 16)

                    // Expected position tick on track
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.iwTertiary)
                        .frame(width: 2, height: 14)
                        .position(x: expectedX, y: trackY)

                    // --- Milestone markers ---
                    ForEach(milestones, id: \.self) { milestone in
                        let mx = trackStart + trackLength * milestone
                        let reached = progress >= milestone
                        Circle()
                            .fill(reached ? Color.iwPrimary : Color.iwSurfaceContainerHigh)
                            .frame(width: 8, height: 8)
                            .position(x: mx, y: trackY)

                        Text("\(Int(milestone * 100))%")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(reached ? Color.iwPrimary : Color.iwOutlineVariant)
                            .position(x: mx, y: trackY + 16)
                    }

                    // --- Goal steps at the end (right side) ---
                    VStack(spacing: 0) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(progress >= 1.0 ? Color.iwPrimary : Color.iwOutlineVariant)
                        Text(goalSteps.formatted())
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.iwOutline)
                    }
                    .position(x: trackEnd, y: trackY - 20)

                    // --- Walking person (above track, no circle background) ---

                    // Step count above walker
                    Text(currentSteps.formatted())
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.iwPrimary)
                        .contentTransition(.numericText())
                        .position(x: walkerX, y: trackY - 80)

                    // Walker icon — large and prominent
                    Image(systemName: "figure.walk")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(Color.iwPrimary)
                        .position(x: walkerX, y: trackY - 36)
                }
            }
            .frame(height: 130)

            // Ahead/behind status label
            HStack(spacing: 4) {
                Image(systemName: isAheadOfSchedule ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                    .font(.system(size: 12))
                Text(isAheadOfSchedule ? "Ahead of schedule!" : "A bit behind — let's walk!")
                    .font(IWFont.labelSmall())
            }
            .foregroundStyle(isAheadOfSchedule ? Color.iwPrimary : Color.iwTertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(currentSteps) of \(goalSteps) steps, \(percentage) percent of goal")
    }
}

// MARK: - Step Progress Ring

struct StepProgressRing: View {
    let currentSteps: Int
    let goalSteps: Int
    let lineWidth: CGFloat
    var animatedProgress: Double?
    var onDarkBackground: Bool = false

    private var progress: Double {
        animatedProgress ?? min(Double(currentSteps) / Double(goalSteps), 1.0)
    }

    private var percentage: Int {
        Int(progress * 100)
    }

    private var labelColor: Color {
        onDarkBackground ? .white.opacity(0.7) : Color.iwOutline
    }

    private var valueColor: Color {
        onDarkBackground ? .white : Color.iwOnSurface
    }

    private var trackColor: Color {
        onDarkBackground ? .white.opacity(0.15) : Color.iwSurfaceContainerHigh
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [.iwPrimary, .iwPrimaryContainer, .iwPrimaryFixed],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * max(progress, 0.01))
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(percentage)% Goal")
                    .font(IWFont.labelMedium())
                    .foregroundStyle(labelColor)
                Text(currentSteps.formatted())
                    .font(IWFont.displayMedium())
                    .foregroundStyle(valueColor)
                    .fontWeight(.bold)
                    .contentTransition(.numericText())
                Text("/ \(goalSteps.formatted()) STEPS")
                    .font(IWFont.labelMedium())
                    .foregroundStyle(labelColor)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(currentSteps) of \(goalSteps) steps, \(percentage) percent of goal")
    }
}

// MARK: - Pill Button

struct PillButton: View {
    let title: String
    let icon: String?
    let isActive: Bool
    let action: () -> Void

    init(_ title: String, icon: String? = nil, isActive: Bool = false, action: @escaping () -> Void = {}) {
        self.title = title
        self.icon = icon
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .symbolEffect(.pulse, isActive: isActive)
                }
                Text(title)
                    .font(IWFont.labelLarge())
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(isActive ? AnyShapeStyle(Color.iwError) : AnyShapeStyle(Color.iwPrimaryGradient))
            .clipShape(Capsule())
        }
        .scaleEffect(isActive ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isActive)
        .accessibilityLabel(title)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let iconColor: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
            Text(value)
                .font(IWFont.titleMedium())
                .foregroundStyle(Color.iwOnSurface)
                .contentTransition(.numericText())
            Text(label)
                .font(IWFont.labelSmall())
                .foregroundStyle(Color.iwOutline)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Info Card

struct InfoCard<Content: View>: View {
    let backgroundColor: Color
    let content: () -> Content

    init(backgroundColor: Color = .iwSurfaceContainerLowest, @ViewBuilder content: @escaping () -> Content) {
        self.backgroundColor = backgroundColor
        self.content = content
    }

    var body: some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - Chip View

struct ChipView: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(IWFont.labelMedium())
            .fontWeight(.medium)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : Color.iwOnSurfaceVariant)
            .background(isSelected ? Color.iwPrimary : Color.iwSurfaceContainerLow)
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Activity Bar Chart

struct ActivityBarChart: View {
    let data: [CGFloat]
    let labels: [String]
    let accentIndex: Int?
    var animated: Bool = true

    @State private var appeared = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(index == accentIndex ? Color.iwPrimary : Color.iwSurfaceContainerHigh)
                        .frame(height: appeared ? value * 80 : 0)
                    if index < labels.count {
                        Text(labels[index])
                            .font(IWFont.labelSmall())
                            .foregroundStyle(index == accentIndex ? Color.iwPrimary : Color.iwOutline)
                            .fontWeight(index == accentIndex ? .semibold : .regular)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            if animated {
                withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                    appeared = true
                }
            } else {
                appeared = true
            }
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let trailing: String?
    let trailingAction: (() -> Void)?

    init(_ title: String, trailing: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.trailing = trailing
        self.trailingAction = action
    }

    var body: some View {
        HStack {
            Text(title)
                .font(IWFont.titleMedium())
                .foregroundStyle(Color.iwOnSurface)
            Spacer()
            if let trailing {
                Button(action: { trailingAction?() }) {
                    Text(trailing)
                        .font(IWFont.labelMedium())
                        .foregroundStyle(Color.iwPrimary)
                }
            }
        }
    }
}

// MARK: - App Header

struct AppHeader: View {
    let showProfile: Bool
    let showSettings: Bool
    let onSettingsTap: (() -> Void)?

    init(
        showProfile: Bool = false,
        showSettings: Bool = true,
        onSettingsTap: (() -> Void)? = nil
    ) {
        self.showProfile = showProfile
        self.showSettings = showSettings
        self.onSettingsTap = onSettingsTap
    }

    var body: some View {
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
            if showProfile {
                Circle()
                    .fill(Color.iwSurfaceContainerHigh)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.iwOutline)
                    )
            }
            if showSettings {
                Button(action: { onSettingsTap?() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.iwOnSurfaceVariant)
                }
                .accessibilityLabel("Settings")
            }
        }
    }
}

// MARK: - Glass Tab Bar

enum TabItem: Int, CaseIterable {
    case daily, insights, coach, habits, badges

    var title: String {
        switch self {
        case .daily: "Daily"
        case .insights: "Insights"
        case .coach: "Coach"
        case .habits: "Habits"
        case .badges: "Badges"
        }
    }

    var icon: String {
        switch self {
        case .daily: "chart.bar.fill"
        case .insights: "brain.head.profile"
        case .coach: "person.fill.questionmark"
        case .habits: "checkmark.circle.fill"
        case .badges: "medal.fill"
        }
    }
}

struct GlassTabBar: View {
    @Binding var selectedTab: TabItem

    var body: some View {
        HStack {
            ForEach(TabItem.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18))
                            .scaleEffect(selectedTab == tab ? 1.15 : 1.0)
                        Text(tab.title)
                            .font(IWFont.labelSmall())
                    }
                    .foregroundStyle(selectedTab == tab ? Color.iwPrimary : Color.iwOnSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Animated Card Wrapper

struct AnimatedCard<Content: View>: View {
    let delay: Double
    let content: () -> Content
    @State private var appeared = false

    init(delay: Double = 0, @ViewBuilder content: @escaping () -> Content) {
        self.delay = delay
        self.content = content
    }

    var body: some View {
        content()
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(delay)) {
                    appeared = true
                }
            }
    }
}
