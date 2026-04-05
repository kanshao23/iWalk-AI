import SwiftUI

struct ContentView: View {
    @AppStorage("hasSubscribed") private var hasSubscribed = false
    @State private var showPaywall = false

    var body: some View {
        MainTabView()
            .onAppear {
                if !hasSubscribed {
                    showPaywall = true
                }
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView()
            }
    }
}

#Preview {
    ContentView()
}
