import SwiftUI

struct PaywallView: View {
    @State private var vm = PaywallViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Background
            Color.iwSurface.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Close & Restore
                    HStack {
                        Button("Restore") { Task { await vm.restore() } }
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwOutline)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.iwOutline)
                                .frame(width: 32, height: 32)
                                .background(Color.iwSurfaceContainerHigh)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // Hero
                    VStack(spacing: 16) {
                        // App icon
                        Circle()
                            .fill(Color.iwPrimaryGradient)
                            .frame(width: 72, height: 72)
                            .overlay(
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .scaleEffect(appeared ? 1 : 0.6)
                            .opacity(appeared ? 1 : 0)

                        Text("Unlock Your\nFull Potential")
                            .font(IWFont.headlineLarge())
                            .foregroundStyle(Color.iwOnSurface)
                            .multilineTextAlignment(.center)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 15)

                        Text("Get unlimited access to AI coaching,\nadvanced insights, and more.")
                            .font(IWFont.bodyMedium())
                            .foregroundStyle(Color.iwOutline)
                            .multilineTextAlignment(.center)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)

                    // Features list
                    VStack(spacing: 0) {
                        ForEach(Array(vm.features.enumerated()), id: \.offset) { index, feature in
                            HStack(spacing: 14) {
                                Image(systemName: feature.icon)
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.iwPrimary)
                                    .frame(width: 40, height: 40)
                                    .background(Color.iwPrimaryFixed.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(feature.title)
                                        .font(IWFont.labelLarge())
                                        .foregroundStyle(Color.iwOnSurface)
                                    Text(feature.description)
                                        .font(IWFont.labelSmall())
                                        .foregroundStyle(Color.iwOutline)
                                }
                                Spacer()
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.iwPrimary)
                            }
                            .padding(.vertical, 12)
                            .opacity(appeared ? 1 : 0)
                            .offset(x: appeared ? 0 : -20)
                            .animation(.easeOut(duration: 0.4).delay(0.3 + Double(index) * 0.08), value: appeared)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Social proof
                    HStack(spacing: 6) {
                        // Avatars stack
                        HStack(spacing: -8) {
                            ForEach(0..<4, id: \.self) { i in
                                Circle()
                                    .fill([Color.iwPrimaryContainer, .iwSecondaryFixedDim, .iwTertiaryContainer, .iwPrimaryFixed][i])
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white)
                                    )
                                    .overlay(Circle().stroke(Color.iwSurface, lineWidth: 2))
                            }
                        }
                        Text(vm.socialProof)
                            .font(IWFont.labelSmall())
                            .foregroundStyle(Color.iwOutline)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 28)

                    // Pricing cards
                    HStack(spacing: 12) {
                        ForEach(PricingPlan.allCases) { plan in
                            PricingCard(
                                plan: plan,
                                displayPrice: vm.displayPrice(for: plan),
                                isSelected: vm.selectedPlan == plan
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    vm.selectedPlan = plan
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // CTA Button
                    Button {
                        Task {
                            let success = await vm.purchase()
                            if success { dismiss() }
                        }
                    } label: {
                        if vm.isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(height: 20)
                        } else {
                            Text("Start 7-Day Free Trial")
                                .font(IWFont.labelLarge())
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.iwPrimary)
                    .clipShape(Capsule())
                    .disabled(vm.isPurchasing)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    if let error = vm.purchaseError {
                        Text(error)
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwError)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    // Billing note
                    Text(billingNote)
                        .font(IWFont.labelSmall())
                        .foregroundStyle(Color.iwOutline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 12)

                    // Legal links
                    HStack(spacing: 16) {
                        Link("Terms of Use", destination: URL(string: "https://www.kanverse.app/iwalk-ai/terms")!)
                            .font(IWFont.labelSmall())
                            .foregroundStyle(Color.iwOutline)
                        Text("·")
                            .foregroundStyle(Color.iwOutlineVariant)
                        Link("Privacy Policy", destination: URL(string: "https://www.kanverse.app/iwalk-ai/privacy")!)
                            .font(IWFont.labelSmall())
                            .foregroundStyle(Color.iwOutline)
                        Text("·")
                            .foregroundStyle(Color.iwOutlineVariant)
                        Link("Support", destination: URL(string: "https://kanverse.app/iwalk-ai")!)
                            .font(IWFont.labelSmall())
                            .foregroundStyle(Color.iwOutline)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }

        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
        .task {
            await vm.loadProducts()
        }
    }

    private var billingNote: String {
        let price = vm.displayPrice(for: vm.selectedPlan)
        switch vm.selectedPlan {
        case .weekly:
            return "After your 7-day free trial, \(price)/week is charged to your Apple ID. Renews automatically. Cancel anytime in App Store Settings."
        case .yearly:
            return "After your 7-day free trial, \(price)/year is charged to your Apple ID. Renews automatically. Cancel anytime in App Store Settings."
        }
    }
}

// MARK: - Pricing Card

private struct PricingCard: View {
    let plan: PricingPlan
    let displayPrice: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Savings badge
            if let badge = plan.savingsBadge {
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.iwPrimary)
                    .clipShape(Capsule())
            } else {
                Spacer().frame(height: 22)
            }

            Text(plan.title)
                .font(IWFont.labelMedium())
                .foregroundStyle(isSelected ? Color.iwOnSurface : Color.iwOutline)

            // Actual billed amount is the most prominent element (Apple 3.1.2)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(displayPrice)
                    .font(IWFont.headlineMedium())
                    .foregroundStyle(isSelected ? Color.iwOnSurface : Color.iwOutline)
                Text(plan.billedPeriod)
                    .font(IWFont.labelSmall())
                    .foregroundStyle(Color.iwOutline)
            }

            if let equivalent = plan.weeklyEquivalent {
                Text(equivalent)
                    .font(IWFont.labelSmall())
                    .foregroundStyle(Color.iwPrimary)
                    .fontWeight(.medium)
            } else {
                Spacer().frame(height: 14)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(isSelected ? Color.iwSurfaceContainerLowest : Color.iwSurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? Color.iwPrimary : .clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityLabel("\(plan.title) plan, \(displayPrice) \(plan.billedPeriod)")
    }
}

