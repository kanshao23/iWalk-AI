import SwiftUI

struct CoinBalanceView: View {
    let balance: Int
    var showLabel: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.iwTertiaryContainer)
            Text("\(balance)")
                .font(IWFont.labelLarge())
                .fontWeight(.semibold)
                .foregroundStyle(Color.iwOnSurface)
                .contentTransition(.numericText())
            if showLabel {
                Text("coins")
                    .font(IWFont.labelSmall())
                    .foregroundStyle(Color.iwOutline)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.iwSurfaceContainerLow)
        .clipShape(Capsule())
    }
}
