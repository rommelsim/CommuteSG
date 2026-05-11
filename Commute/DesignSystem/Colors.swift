import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    init(light: Color, dark: Color) {
        self.init(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

extension Color {
    static let appBackground = Color(
        light: Color(hex: 0xF1EFE8),
        dark:  Color(hex: 0x050507)
    )
    static let appSurface = Color(
        light: Color(hex: 0xFFFFFF),
        dark:  Color(hex: 0x0F0F11)
    )
    static let appSurface2 = Color(
        light: Color(hex: 0xF1EFE8),
        dark:  Color(hex: 0x1A1A1C)
    )
    static let appBorder = Color(
        light: Color(hex: 0x000000, opacity: 0.08),
        dark:  Color(hex: 0xFFFFFF, opacity: 0.08)
    )
    static let appBorderStrong = Color(
        light: Color(hex: 0x000000, opacity: 0.15),
        dark:  Color(hex: 0xFFFFFF, opacity: 0.15)
    )
    static let appText = Color(
        light: Color(hex: 0x1A1A1C),
        dark:  Color(hex: 0xF1EFE8)
    )
    static let appText2 = Color(
        light: Color(hex: 0x5F5E5A),
        dark:  Color(hex: 0xB4B2A9)
    )
    static let appText3 = Color(
        light: Color(hex: 0x888780),
        dark:  Color(hex: 0x888780)
    )

    static let appInfo = Color(
        light: Color(hex: 0x185FA5),
        dark:  Color(hex: 0x85B7EB)
    )
    static let appInfoBg = Color(
        light: Color(hex: 0xE6F1FB),
        dark:  Color(hex: 0x042C53)
    )
    static let appInfoStrong = Color(
        light: Color(hex: 0x042C53),
        dark:  Color(hex: 0xB5D4F4)
    )

    static let appSuccess = Color(
        light: Color(hex: 0x3B6D11),
        dark:  Color(hex: 0x97C459)
    )
    static let appSuccessBg = Color(
        light: Color(hex: 0xEAF3DE),
        dark:  Color(hex: 0x173404)
    )
    static let appSuccessStrong = Color(
        light: Color(hex: 0x173404),
        dark:  Color(hex: 0xC0DD97)
    )

    static let appWarning = Color(
        light: Color(hex: 0x854F0B),
        dark:  Color(hex: 0xEF9F27)
    )
    static let appWarningBg = Color(
        light: Color(hex: 0xFAEEDA),
        dark:  Color(hex: 0x412402)
    )
    static let appWarningStrong = Color(
        light: Color(hex: 0x412402),
        dark:  Color(hex: 0xFAC775)
    )

    static let appDanger = Color(
        light: Color(hex: 0xA32D2D),
        dark:  Color(hex: 0xF09595)
    )
    static let appDangerBg = Color(
        light: Color(hex: 0xFCEBEB),
        dark:  Color(hex: 0x501313)
    )
    static let appDangerStrong = Color(
        light: Color(hex: 0x501313),
        dark:  Color(hex: 0xF7C1C1)
    )

    static let appPurple = Color(
        light: Color(hex: 0x534AB7),
        dark:  Color(hex: 0xAFA9EC)
    )
    static let appPurpleBg = Color(
        light: Color(hex: 0xEEEDFE),
        dark:  Color(hex: 0x26215C)
    )
    static let appPurpleStrong = Color(
        light: Color(hex: 0x3C3489),
        dark:  Color(hex: 0xCECBF6)
    )

    static let appAmber = Color(
        light: Color(hex: 0xBA7517),
        dark:  Color(hex: 0xEF9F27)
    )

    static let appDestination = Color(hex: 0xD85A30)
    static let appBadgeDot = Color(hex: 0xE24B4A)
}

// MARK: - Crowd-encoding tokens
//
// These drive the arrival-pill background, text, and 3-bar gauge. They map
// roughly onto the existing semantic colors (success/warning/danger), but are
// kept as their own tokens so the pill semantics stay independent of the
// generic status palette.

extension Color {
    // Seats available — green
    static let crowdSeats        = Color(light: Color(hex: 0xEAF3DE), dark: Color(hex: 0x173404))
    static let crowdSeatsText    = Color(light: Color(hex: 0x173404), dark: Color(hex: 0xEAF3DE))
    static let crowdSeatsBars    = Color(light: Color(hex: 0x3B6D11), dark: Color(hex: 0x97C459))

    // Standing only — amber
    static let crowdStanding     = Color(light: Color(hex: 0xFAEEDA), dark: Color(hex: 0x412402))
    static let crowdStandingText = Color(light: Color(hex: 0x412402), dark: Color(hex: 0xFAEEDA))
    static let crowdStandingBars = Color(light: Color(hex: 0x854F0B), dark: Color(hex: 0xEF9F27))

    // Packed — red
    static let crowdPacked       = Color(light: Color(hex: 0xFCEBEB), dark: Color(hex: 0x501313))
    static let crowdPackedText   = Color(light: Color(hex: 0x501313), dark: Color(hex: 0xFCEBEB))
    static let crowdPackedBars   = Color(light: Color(hex: 0xA32D2D), dark: Color(hex: 0xF09595))

    // Unknown — neutral
    static let crowdUnknown      = Color(light: Color(hex: 0xF1EFE8), dark: Color(hex: 0x1A1A1C))
    static let crowdUnknownText  = Color(light: Color(hex: 0x2C2C2A), dark: Color(hex: 0xF1EFE8))
    static let crowdUnknownBars  = Color(light: Color(hex: 0x888780), dark: Color(hex: 0x5F5E5A))
}
