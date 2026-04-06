import SwiftUI

struct AIInsightsView: View {
    @State private var vm = InsightsViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                // Hero Text
                AnimatedCard(delay: 0.1) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your future\nhealth,\ndecoded.")
                            .font(IWFont.headlineLarge())
                            .foregroundStyle(Color.iwOnSurface)
                            .lineSpacing(4)

                        Text("Based on your last 90 days of walking data, here's what your body is telling us.")
                            .font(IWFont.bodyMedium())
                            .foregroundStyle(Color.iwOutline)
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

                // Insight Card (changes with selected category)
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

                                // Animated chart
                                HStack(alignment: .bottom, spacing: 4) {
                                    ForEach(Array(insight.chartData.enumerated()), id: \.offset) { i, value in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(vm.selectedCategory.color.opacity(0.4 + value * 0.6))
                                            .frame(height: vm.chartAnimated ? value * 50 : 0)
                                            .animation(
                                                .easeOut(duration: 0.4).delay(Double(i) * 0.02),
                                                value: vm.chartAnimated
                                            )
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
                    .id(vm.selectedCategory) // Force re-render on category change
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

                // Coach Recommendations (moved from Coach tab)
                AnimatedCard(delay: 0.15) {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader("Coach Recommendations")

                        VStack(spacing: 12) {
                            ForEach(vm.coachRecommendations) { recommendation in
                                InfoCard(backgroundColor: recommendation.backgroundColor.opacity(0.2)) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: recommendation.icon)
                                                .foregroundStyle(recommendation.iconColor)
                                            Text(recommendation.title)
                                                .font(IWFont.titleMedium())
                                                .foregroundStyle(Color.iwOnSurface)
                                            Spacer()
                                            Image(systemName: vm.expandedCoachRecommendationId == recommendation.id ? "chevron.up" : "chevron.down")
                                                .font(.system(size: 12))
                                                .foregroundStyle(Color.iwOutline)
                                        }
                                        Text(recommendation.description)
                                            .font(IWFont.bodyMedium())
                                            .foregroundStyle(Color.iwOutline)

                                        if vm.expandedCoachRecommendationId == recommendation.id {
                                            Divider()
                                            Text(recommendation.detailedInfo)
                                                .font(IWFont.bodyMedium())
                                                .foregroundStyle(Color.iwOnSurfaceVariant)
                                                .transition(.opacity.combined(with: .move(edge: .top)))
                                        }
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { vm.toggleCoachRecommendation(recommendation) }
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
                            HStack {
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
                                Spacer()
                            }
                        }
                    }
                }

                // Weekly Summary
                AnimatedCard(delay: 0.3) {
                    InfoCard(backgroundColor: .iwSecondaryFixed.opacity(0.2)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weekly Summary")
                                .font(IWFont.titleMedium())
                                .foregroundStyle(Color.iwOnSurface)
                            HStack(spacing: 24) {
                                VStack(alignment: .leading) {
                                    Text("\(vm.weeklySummary.totalSteps / 1000)k")
                                        .font(IWFont.headlineMedium())
                                        .foregroundStyle(Color.iwSecondary)
                                    Text("steps last week")
                                        .font(IWFont.labelMedium())
                                        .foregroundStyle(Color.iwOutline)
                                }
                                VStack(alignment: .leading) {
                                    Text("+\(vm.weeklySummary.percentChangeVsPrevious)%")
                                        .font(IWFont.headlineMedium())
                                        .foregroundStyle(Color.iwPrimary)
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
        .onAppear { vm.animateOnAppear() }
    }
}
