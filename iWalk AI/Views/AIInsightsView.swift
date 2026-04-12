import SwiftUI

struct AIInsightsView: View {
    @State private var vm = InsightsViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {

                // Hero Text
                AnimatedCard(delay: 0.1) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your health,\ndecoded.")
                            .font(IWFont.headlineLarge())
                            .foregroundStyle(Color.iwOnSurface)
                            .lineSpacing(4)
                        Text("AI-powered insights built from your real walking data.")
                            .font(IWFont.bodyMedium())
                            .foregroundStyle(Color.iwOutline)
                    }
                }

                // Weekly Health Report
                if let report = vm.weeklyReport {
                    AnimatedCard(delay: 0.12) {
                        WeeklyReportCard(report: report)
                    }
                }

                // Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(MetricCategory.allCases) { category in
                            ChipView(title: category.rawValue, isSelected: category == vm.selectedCategory)
                                .onTapGesture { vm.selectCategory(category) }
                        }
                    }
                }

                // Insight Card
                if let insight = vm.currentInsight {
                    AnimatedCard(delay: 0) {
                        InfoCard(backgroundColor: .iwSurfaceContainerLowest) {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text(insight.title)
                                        .font(IWFont.titleMedium())
                                        .foregroundStyle(Color.iwOnSurface)
                                    Spacer()
                                    Image(systemName: vm.selectedCategory.icon)
                                        .foregroundStyle(vm.selectedCategory.color)
                                }
                                Text(insight.description)
                                    .font(IWFont.bodyMedium())
                                    .foregroundStyle(Color.iwOutline)

                                // Animated bar chart
                                HStack(alignment: .bottom, spacing: 4) {
                                    ForEach(Array(insight.chartData.enumerated()), id: \.offset) { i, value in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(vm.selectedCategory.color.opacity(0.4 + value * 0.6))
                                            .frame(height: vm.chartAnimated ? value * 50 : 0)
                                            .animation(.easeOut(duration: 0.4).delay(Double(i) * 0.02), value: vm.chartAnimated)
                                    }
                                }
                                .frame(height: 50)

                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Projected")
                                            .font(IWFont.labelSmall())
                                            .foregroundStyle(Color.iwOutline)
                                        Text(insight.projectionText)
                                            .font(IWFont.labelMedium())
                                            .foregroundStyle(Color.iwPrimary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                    .id(vm.selectedCategory)
                }

                // AI Recommended Focus
                if let focus = vm.currentFocus {
                    AnimatedCard(delay: 0.1) {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader("AI Recommended Focus")
                            InfoCard(backgroundColor: vm.selectedCategory.color.opacity(0.1)) {
                                HStack(spacing: 14) {
                                    Image(systemName: focus.icon)
                                        .font(.system(size: 24))
                                        .foregroundStyle(vm.selectedCategory.color)
                                        .frame(width: 48, height: 48)
                                        .background(vm.selectedCategory.color.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(focus.title)
                                            .font(IWFont.titleMedium())
                                            .foregroundStyle(Color.iwOnSurface)
                                        Text(focus.description)
                                            .font(IWFont.bodyMedium())
                                            .foregroundStyle(Color.iwOutline)
                                    }
                                }
                            }
                        }
                    }
                    .id("focus-\(vm.selectedCategory)")
                }

                // Coach Recommendations
                AnimatedCard(delay: 0.15) {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader("Coach Recommendations")
                        VStack(spacing: 12) {
                            ForEach(vm.coachRecommendations) { rec in
                                InfoCard(backgroundColor: rec.backgroundColor.opacity(0.2)) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: rec.icon).foregroundStyle(rec.iconColor)
                                            Text(rec.title)
                                                .font(IWFont.titleMedium())
                                                .foregroundStyle(Color.iwOnSurface)
                                            Spacer()
                                            Image(systemName: vm.expandedCoachRecommendationId == rec.id ? "chevron.up" : "chevron.down")
                                                .font(.system(size: 12))
                                                .foregroundStyle(Color.iwOutline)
                                        }
                                        Text(rec.description)
                                            .font(IWFont.bodyMedium())
                                            .foregroundStyle(Color.iwOutline)
                                        if vm.expandedCoachRecommendationId == rec.id {
                                            Divider()
                                            Text(rec.detailedInfo)
                                                .font(IWFont.bodyMedium())
                                                .foregroundStyle(Color.iwOnSurfaceVariant)
                                                .transition(.opacity.combined(with: .move(edge: .top)))
                                        }
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { vm.toggleCoachRecommendation(rec) }
                            }
                        }

                        InfoCard(backgroundColor: .iwSurfaceContainerLow) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.iwPrimary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(vm.natureTipTitle)
                                        .font(IWFont.labelMedium())
                                        .foregroundStyle(Color.iwPrimary)
                                    Text(vm.natureTipDescription)
                                        .font(IWFont.bodyMedium())
                                        .foregroundStyle(Color.iwOutline)
                                }
                            }
                        }
                    }
                }

                // Peak Hours
                AnimatedCard(delay: 0.2) {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader("Your Peak Hours")
                        InfoCard(backgroundColor: .iwSurfaceContainerLowest) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Best performance window")
                                    .font(IWFont.labelMedium())
                                    .foregroundStyle(Color.iwOutline)
                                Text("\(vm.weeklySummary.peakHoursStart) – \(vm.weeklySummary.peakHoursEnd)")
                                    .font(IWFont.titleLarge())
                                    .foregroundStyle(Color.iwOnSurface)
                                Text(vm.weeklySummary.peakHoursNote)
                                    .font(IWFont.bodyMedium())
                                    .foregroundStyle(Color.iwOutline)
                                    .padding(.top, 4)
                            }
                        }
                    }
                }

                // Weekly Step Summary
                AnimatedCard(delay: 0.3) {
                    InfoCard(backgroundColor: .iwSecondaryFixed.opacity(0.2)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weekly Summary")
                                .font(IWFont.titleMedium())
                                .foregroundStyle(Color.iwOnSurface)
                            HStack(spacing: 24) {
                                VStack(alignment: .leading) {
                                    Text("\(vm.weeklySummary.totalSteps / 1_000)k")
                                        .font(IWFont.headlineMedium())
                                        .foregroundStyle(Color.iwSecondary)
                                    Text("steps this week")
                                        .font(IWFont.labelMedium())
                                        .foregroundStyle(Color.iwOutline)
                                }
                                VStack(alignment: .leading) {
                                    let pct = vm.weeklySummary.percentChangeVsPrevious
                                    Text(pct >= 0 ? "+\(pct)%" : "\(pct)%")
                                        .font(IWFont.headlineMedium())
                                        .foregroundStyle(pct >= 0 ? Color.iwPrimary : Color.iwError)
                                    Text("vs. previous week")
                                        .font(IWFont.labelMedium())
                                        .foregroundStyle(Color.iwOutline)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(Color.iwSurface)
        .task { await vm.loadRealData() }
        .onAppear { vm.animateOnAppear() }
    }
}

// MARK: - Weekly Health Report Card

private struct WeeklyReportCard: View {
    let report: WeeklyReport

    var body: some View {
        InfoCard(backgroundColor: .iwSurfaceContainerLowest) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weekly Health Report")
                            .font(IWFont.titleMedium())
                            .foregroundStyle(Color.iwOnSurface)
                        Text("Based on your HealthKit data")
                            .font(IWFont.labelSmall())
                            .foregroundStyle(Color.iwOutline)
                    }
                    Spacer()
                    Text(report.grade)
                        .font(IWFont.labelMedium())
                        .fontWeight(.semibold)
                        .foregroundStyle(report.gradeColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(report.gradeColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                Divider()

                // Stats grid
                HStack(spacing: 0) {
                    ReportStat(value: "\(report.totalSteps.formatted())", label: "steps", icon: "figure.walk")
                    Divider().frame(height: 36)
                    ReportStat(value: "\(report.totalCalories.formatted())", label: "kcal", icon: "flame.fill")
                    Divider().frame(height: 36)
                    ReportStat(value: String(format: "%.1f", report.totalDistanceKm), label: "km", icon: "map.fill")
                }

                HStack(spacing: 16) {
                    Label("\(report.activeDays)/7 active days", systemImage: "calendar.badge.checkmark")
                        .font(IWFont.labelSmall())
                        .foregroundStyle(Color.iwOutline)
                    Spacer()
                    if report.bestDaySteps > 0 {
                        Label("Best: \(report.bestDayName) (\(report.bestDaySteps.formatted()))", systemImage: "trophy.fill")
                            .font(IWFont.labelSmall())
                            .foregroundStyle(Color.iwOutline)
                    }
                }

                if report.weekOverWeekChange != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: report.weekOverWeekChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                        Text("\(report.changeLabel) vs last week")
                            .font(IWFont.labelSmall())
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(report.weekOverWeekChange >= 0 ? Color.iwPrimary : Color.iwError)
                }
            }
        }
    }
}

private struct ReportStat: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.iwPrimary)
            Text(value)
                .font(IWFont.titleMedium())
                .foregroundStyle(Color.iwOnSurface)
                .monospacedDigit()
            Text(label)
                .font(IWFont.labelSmall())
                .foregroundStyle(Color.iwOutline)
        }
        .frame(maxWidth: .infinity)
    }
}
