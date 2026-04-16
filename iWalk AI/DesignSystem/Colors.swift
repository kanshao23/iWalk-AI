import SwiftUI

extension Color {
    // MARK: - Primary
    static let iwPrimary = Color(hex: 0x006C51)
    static let iwPrimaryContainer = Color(hex: 0x00D1A0)
    static let iwOnPrimary = Color.white
    static let iwOnPrimaryContainer = Color(hex: 0x00543E)
    static let iwPrimaryFixed = Color(hex: 0x58FDC8)
    static let iwPrimaryFixedDim = Color(hex: 0x2EE0AD)

    // MARK: - Secondary
    static let iwSecondary = Color(hex: 0x0C6780)
    static let iwSecondaryContainer = Color(hex: 0x9AE1FF)
    static let iwOnSecondary = Color.white
    static let iwOnSecondaryContainer = Color(hex: 0x09657F)
    static let iwSecondaryFixed = Color(hex: 0xBAEAFF)
    static let iwSecondaryFixedDim = Color(hex: 0x89D0ED)

    // MARK: - Tertiary
    static let iwTertiary = Color(hex: 0x924C02)
    static let iwTertiaryContainer = Color(hex: 0xFFA359)
    static let iwOnTertiary = Color.white
    static let iwTertiaryFixed = Color(hex: 0xFFDCC4)
    static let iwTertiaryFixedDim = Color(hex: 0xFFB781)

    // MARK: - Surface
    static let iwSurface = Color(hex: 0xFCF8FB)
    static let iwSurfaceBright = Color(hex: 0xFCF8FB)
    static let iwSurfaceContainer = Color(hex: 0xF0EDEF)
    static let iwSurfaceContainerHigh = Color(hex: 0xEAE7EA)
    static let iwSurfaceContainerHighest = Color(hex: 0xE4E2E4)
    static let iwSurfaceContainerLow = Color(hex: 0xF6F3F5)
    static let iwSurfaceContainerLowest = Color.white
    static let iwSurfaceDim = Color(hex: 0xDCD9DC)
    static let iwSurfaceVariant = Color(hex: 0xE4E2E4)

    // MARK: - On Surface
    static let iwOnSurface = Color(hex: 0x1B1B1D)
    static let iwOnSurfaceVariant = Color(hex: 0x3B4A43)
    static let iwInverseOnSurface = Color(hex: 0xF3F0F2)
    static let iwInverseSurface = Color(hex: 0x303032)
    static let iwInversePrimary = Color(hex: 0x2EE0AD)

    // MARK: - Outline
    static let iwOutline = Color(hex: 0x6B7B73)
    static let iwOutlineVariant = Color(hex: 0xBACAC1)

    // MARK: - Error
    static let iwError = Color(hex: 0xBA1A1A)
    static let iwErrorContainer = Color(hex: 0xFFDAD6)
    static let iwOnError = Color.white

    // MARK: - Background
    static let iwBackground = Color(hex: 0xFCF8FB)
    static let iwOnBackground = Color(hex: 0x1B1B1D)

    // MARK: - Gradients
    static var iwPrimaryGradient: LinearGradient {
        LinearGradient(
            colors: [iwPrimary, iwPrimaryContainer],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var iwEveningGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x004030), Color(hex: 0x005C45)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let iwEvening = Color(hex: 0x004030)
    static let iwEveningAccent = Color(hex: 0x00D1A0)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
