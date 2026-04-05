import SwiftUI

struct CoinToast: View {
    let amount: Int
    let source: CoinSource

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: source.icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.iwTertiaryContainer)

            Text("+\(amount)")
                .font(IWFont.titleMedium())
                .fontWeight(.bold)
                .foregroundStyle(Color.iwTertiaryContainer)

            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.iwTertiaryContainer)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.iwOnSurface.opacity(0.9))
        .clipShape(Capsule())
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
