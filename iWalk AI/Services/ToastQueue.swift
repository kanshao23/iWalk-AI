import SwiftUI

struct ToastItem: Identifiable {
    let id = UUID()
    let amount: Int
    let source: CoinSource
}

@Observable
@MainActor
final class ToastQueue {
    static let shared = ToastQueue()

    var current: ToastItem?
    private var queue: [ToastItem] = []
    private var isShowing = false

    private init() {}

    func enqueue(amount: Int, source: CoinSource) {
        let item = ToastItem(amount: amount, source: source)
        queue.append(item)
        if !isShowing {
            showNext()
        }
    }

    private func showNext() {
        guard !queue.isEmpty else {
            isShowing = false
            return
        }
        isShowing = true
        let item = queue.removeFirst()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            current = item
        }
        Task {
            try? await Task.sleep(for: .seconds(2.0))
            withAnimation(.easeOut(duration: 0.3)) {
                self.current = nil
            }
            try? await Task.sleep(for: .seconds(0.35))
            self.showNext()
        }
    }
}
