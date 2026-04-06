//
//  iWalk_AIApp.swift
//  iWalk AI
//
//  Created by Kan Shao on 2026/3/27.
//

import SwiftUI

// MARK: - Environment Keys

struct CoinViewModelKey: EnvironmentKey {
    static let defaultValue = CoinViewModel()
}

struct StreakViewModelKey: EnvironmentKey {
    static let defaultValue = StreakViewModel()
}

struct JourneyViewModelKey: EnvironmentKey {
    static let defaultValue = JourneyViewModel()
}

extension EnvironmentValues {
    var coinVM: CoinViewModel {
        get { self[CoinViewModelKey.self] }
        set { self[CoinViewModelKey.self] = newValue }
    }

    var streakVM: StreakViewModel {
        get { self[StreakViewModelKey.self] }
        set { self[StreakViewModelKey.self] = newValue }
    }

    var journeyVM: JourneyViewModel {
        get { self[JourneyViewModelKey.self] }
        set { self[JourneyViewModelKey.self] = newValue }
    }
}

@main
struct iWalk_AIApp: App {
    @State private var coinVM = CoinViewModel()
    @State private var streakVM = StreakViewModel()
    @State private var journeyVM = JourneyViewModel()

    init() {
        _ = StoreKitManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.coinVM, coinVM)
                .environment(\.streakVM, streakVM)
                .environment(\.journeyVM, journeyVM)
        }
    }
}
