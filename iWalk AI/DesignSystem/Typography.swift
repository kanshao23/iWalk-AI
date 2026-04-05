import SwiftUI

struct IWFont {
    // Using system rounded as Manrope alternative, system default as Be Vietnam Pro alternative
    static func displayLarge() -> Font {
        .system(size: 56, weight: .bold, design: .rounded)
    }

    static func displayMedium() -> Font {
        .system(size: 40, weight: .bold, design: .rounded)
    }

    static func headlineLarge() -> Font {
        .system(size: 32, weight: .semibold, design: .rounded)
    }

    static func headlineMedium() -> Font {
        .system(size: 28, weight: .medium, design: .rounded)
    }

    static func titleLarge() -> Font {
        .system(size: 22, weight: .semibold)
    }

    static func titleMedium() -> Font {
        .system(size: 18, weight: .semibold)
    }

    static func bodyLarge() -> Font {
        .system(size: 16, weight: .regular)
    }

    static func bodyMedium() -> Font {
        .system(size: 14, weight: .regular)
    }

    static func labelLarge() -> Font {
        .system(size: 14, weight: .medium)
    }

    static func labelMedium() -> Font {
        .system(size: 12, weight: .medium)
    }

    static func labelSmall() -> Font {
        .system(size: 11, weight: .medium)
    }
}
