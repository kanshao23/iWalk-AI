import SwiftUI

struct ContentView: View {
    var body: some View {
        MainTabView()
            .task {
                // Refresh purchase state on every launch
                await StoreKitManager.shared.refreshEntitlements()
            }
    }
}

#Preview {
    ContentView()
}
