import SwiftUI

/// Colour palette for Live Activity / Dynamic Island surfaces. Per the
/// handoff, the Live Activity target uses Tailwind hexes for MRT line chips
/// rather than the in-app LTA palette — keeps the dark-on-dark widget surface
/// readable against the always-dark Activity background.
enum LATheme {
    static let liveGreen = Color(red: 0.114, green: 0.620, blue: 0.459)
    static let liveGreenBright = Color(red: 0.306, green: 0.824, blue: 0.627)

    static func lineColor(for code: String) -> Color {
        switch String(code.prefix(2)) {
        case "EW": Color(red: 0.086, green: 0.639, blue: 0.290) // 16a34a
        case "NS": Color(red: 0.863, green: 0.149, blue: 0.149) // dc2626
        case "NE": Color(red: 0.576, green: 0.200, blue: 0.918) // 9333ea
        case "CC": Color(red: 0.918, green: 0.345, blue: 0.047) // ea580c
        case "DT": Color(red: 0.114, green: 0.306, blue: 0.847) // 1d4ed8
        case "TE": Color(red: 0.573, green: 0.251, blue: 0.055) // 92400e
        default:   Color.gray
        }
    }
}
