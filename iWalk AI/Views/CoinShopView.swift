import SwiftUI

struct CoinShopView: View {
    @Environment(\.dismiss) private var dismiss
    var coinVM: CoinViewModel
    var streakVM: StreakViewModel

    private struct ShopItem {
        let id: String
        let icon: String
        let title: String
        let description: String
        let price: Int
        let isConsumable: Bool
    }

    private let items: [ShopItem] = [
        ShopItem(id: "freeze_card", icon: "snowflake", title: "Freeze Card",
                 description: "Protect your streak if you miss a day.", price: 20, isConsumable: true),
        ShopItem(id: "theme_aurora", icon: "sparkles", title: "Aurora Journey",
                 description: "Northern lights color theme for your journey.", price: 50, isConsumable: false),
        ShopItem(id: "theme_forest", icon: "leaf.fill", title: "Forest Journey",
                 description: "Deep green forest theme for your journey.", price: 50, isConsumable: false),
        ShopItem(id: "theme_galaxy", icon: "moon.stars.fill", title: "Galaxy Journey",
                 description: "Cosmic deep-space theme for your journey.", price: 50, isConsumable: false),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.iwSurface.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Balance header
                        HStack(spacing: 8) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.iwPrimaryFixed)
                            Text("\(coinVM.account.balance) coins")
                                .font(IWFont.titleLarge())
                                .foregroundStyle(Color.iwOnSurface)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.iwSurfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)

                        // Items
                        VStack(spacing: 12) {
                            ForEach(items, id: \.id) { item in
                                shopItemRow(item)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Coin Shop")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(IWFont.labelLarge())
                        .foregroundStyle(Color.iwPrimary)
                }
            }
        }
    }

    private func shopItemRow(_ item: ShopItem) -> some View {
        let isOwned = !item.isConsumable && coinVM.unlockedThemes.contains(item.id)
        let canAfford = coinVM.account.balance >= item.price

        return HStack(spacing: 14) {
            Circle()
                .fill(Color.iwSecondaryFixed)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: item.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(Color.iwSecondary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(IWFont.labelLarge())
                    .foregroundStyle(Color.iwOnSurface)
                Text(item.description)
                    .font(IWFont.labelMedium())
                    .foregroundStyle(Color.iwOutline)
                    .lineLimit(2)
            }

            Spacer()

            if isOwned {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.iwPrimary)
            } else {
                Button {
                    _ = coinVM.unlockTheme(item.id, streakVM: streakVM)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 12))
                        Text("\(item.price)")
                            .font(IWFont.labelLarge())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(canAfford ? Color.iwPrimary : Color.iwSurfaceContainerHigh)
                    .foregroundStyle(canAfford ? Color.white : Color.iwOutline)
                    .clipShape(Capsule())
                }
                .disabled(!canAfford)
            }
        }
        .padding(14)
        .background(Color.iwSurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
