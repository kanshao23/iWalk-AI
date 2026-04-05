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
                        Button("Restore") { vm.restore() }
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwOutline)
                        Spacer()
                        Button { handleDismiss() } label: {
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
                        vm.purchase()
                    } label: {
                        HStack(spacing: 8) {
                            if vm.isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Start My 7-Day Free Trial")
                                    .font(IWFont.titleMedium())
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.iwPrimaryGradient)
                        .clipShape(Capsule())
                    }
                    .disabled(vm.isPurchasing)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    // Billing note
                    Text(billingNote)
                        .font(IWFont.labelSmall())
                        .foregroundStyle(Color.iwOutline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 12)

                    // Legal links
                    HStack(spacing: 16) {
                        Button("Terms of Use") {}
                            .font(IWFont.labelSmall())
                            .foregroundStyle(Color.iwOutline)
                        Text("·")
                            .foregroundStyle(Color.iwOutlineVariant)
                        Button("Privacy Policy") {}
                            .font(IWFont.labelSmall())
                            .foregroundStyle(Color.iwOutline)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }

            // Retention offer overlay
            if vm.showRetentionOffer {
                RetentionOfferView(
                    price: vm.retentionPrice,
                    onAccept: {
                        vm.showRetentionOffer = false
                        vm.purchase()
                    },
                    onDecline: {
                        vm.declineRetention()
                        dismiss()
                    }
                )
                .transition(.opacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }

    private var billingNote: String {
        switch vm.selectedPlan {
        case .weekly:
            "Billed $2.99 every week. Cancel anytime in Settings."
        case .yearly:
            "Billed $39.99 per year. Cancel anytime in Settings."
        }
    }

    private func handleDismiss() {
        if vm.showRetentionOffer {
            vm.declineRetention()
            dismiss()
        } else {
            vm.dismiss()
        }
    }
}

// MARK: - Pricing Card

private struct PricingCard: View {
    let plan: PricingPlan
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

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(plan.price)
                    .font(IWFont.headlineMedium())
                    .foregroundStyle(isSelected ? Color.iwOnSurface : Color.iwOutline)
                Text(plan.period)
                    .font(IWFont.labelSmall())
                    .foregroundStyle(Color.iwOutline)
            }

            if let perWeek = plan.perWeekPrice {
                Text(perWeek)
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
        .accessibilityLabel("\(plan.title) plan, \(plan.price) \(plan.period)")
    }
}

// MARK: - Retention Offer

private struct RetentionOfferView: View {
    let price: String
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onDecline() }

            VStack(spacing: 20) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.iwPrimaryContainer)

                Text("Wait — special offer!")
                    .font(IWFont.titleLarge())
                    .foregroundStyle(Color.iwOnSurface)

                Text("Get a full year of iWalk AI Premium for just \(price). That's our best deal ever.")
                    .font(IWFont.bodyMedium())
                    .foregroundStyle(Color.iwOutline)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    Button(action: onAccept) {
                        Text("Claim \(price)")
                            .font(IWFont.labelLarge())
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.iwPrimaryGradient)
                            .clipShape(Capsule())
                    }

                    Button(action: onDecline) {
                        Text("No thanks")
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwOutline)
                    }
                }
            }
            .padding(28)
            .background(Color.iwSurfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .padding(.horizontal, 28)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }
}
