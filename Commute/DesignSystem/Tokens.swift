import SwiftUI

// MARK: - CM design tokens
// New design language ("CM" prefix) introduced alongside the existing
// `app*` tokens during a staged rollout. Existing screens continue to use
// `Color.app*` / `Spacing.*` / `Radius.*`. New screens that adopt the
// design language documented in DESIGN_LANGUAGE.md use these.

extension Color {
    // Brand
    static let cmAccent = Color(hex: 0x0C447C)

    // Semantic
    static let cmLive = Color(hex: 0x006A4E)

    // Home / Work card tints
    static let cmHomeTintBG = Color(hex: 0xD6E4F5)
    static let cmHomeTintFG = Color(hex: 0x0C447C)
    static let cmWorkTintBG = Color(hex: 0xE0DDF5)
    static let cmWorkTintFG = Color(hex: 0x3C3489)

    // Hairline border used across CM cards
    static var cmHairline: Color { Color.primary.opacity(0.08) }
}

// MARK: - CM line color resolver
// Separate from the data-layer `MRTLine` enum (Models/MRTLine.swift). Lives
// in the design system so the pill component can map a station code prefix
// (incl. LRT lines that the data layer doesn't model) to its authentic
// LTA palette color without entangling presentation with the domain model.
enum MRTLineToken {
    case northSouth, eastWest, circle, northEast, downtown
    case thomsonEastCoast, changiAirport, bukitPanjangLRT, sengkangLRT, punggolLRT

    var color: Color {
        switch self {
        case .northSouth:        return Color(hex: 0xD42E12)
        case .eastWest, .changiAirport: return Color(hex: 0x006A4E)
        case .circle:            return Color(hex: 0xFA9E0D)
        case .northEast:         return Color(hex: 0x9E28B5)
        case .downtown:          return Color(hex: 0x005EC4)
        case .thomsonEastCoast:  return Color(hex: 0x9D5B25)
        case .bukitPanjangLRT,
             .sengkangLRT,
             .punggolLRT:        return Color(hex: 0x748477)
        }
    }

    static func from(code: String) -> MRTLineToken? {
        let prefix = code.prefix { $0.isLetter }
        switch prefix.uppercased() {
        case "NS": return .northSouth
        case "EW": return .eastWest
        case "CC", "CE": return .circle
        case "NE": return .northEast
        case "DT": return .downtown
        case "TE": return .thomsonEastCoast
        case "CG": return .changiAirport
        case "BP": return .bukitPanjangLRT
        case "SE", "SW": return .sengkangLRT
        case "PE", "PW": return .punggolLRT
        default: return nil
        }
    }
}

// MARK: - "Commute Flow" redesign tokens (DESIGN_SPEC.md)
// A second design system layered on top of CM, used by the redesigned Home
// screen. Distinct visual vocabulary: glass surfaces, time-of-day hero,
// neutral bus chips, dark NOW pill. Saturated colors are reserved for MRT.

extension Color {
    // Page surface
    static let cfPageBackground = Color(hex: 0xF2F2F5)

    // Glass card surface (translucent white)
    static let cfGlassFill          = Color.white.opacity(0.75)
    static let cfGlassFillStrong    = Color.white.opacity(0.85)
    static let cfGlassFillSoft      = Color.white.opacity(0.70)
    static let cfHairline           = Color.black.opacity(0.04)
    static let cfHairlineStrong     = Color.black.opacity(0.08)

    // Text on light surfaces
    static let cfTextPrimary        = Color.black
    static let cfTextSecondary      = Color.black.opacity(0.55)
    static let cfTextTertiary       = Color.black.opacity(0.45)
    static let cfTextMuted          = Color.black.opacity(0.30)
    static let cfTextDisabled       = Color.black.opacity(0.20)

    // Text on dark hero
    static let cfOnDarkPrimary      = Color.white
    static let cfOnDarkSecondary    = Color.white.opacity(0.70)
    static let cfOnDarkMuted        = Color.white.opacity(0.55)
    static let cfOnDarkLabel        = Color.white.opacity(0.45)

    // Bus service chip
    static let cfChipFill           = Color.black.opacity(0.05)
    static let cfChipText           = Color(hex: 0x1F2937)
    static let cfChipBorder         = Color.black.opacity(0.08)
    static let cfChipOnDarkFill     = Color.white.opacity(0.95)
    static let cfChipOnDarkText     = Color(hex: 0x0F172A)

    // The dark NOW pill — only fully-dark element in the UI
    static let cfNowFill            = Color(hex: 0x0F172A)

    // Crowd indicator
    static let cfCrowdFilled        = Color.black.opacity(0.55)
    static let cfCrowdEmpty         = Color.black.opacity(0.12)

    // Live / status
    static let cfLiveDot            = Color(hex: 0x16A34A)
    static let cfStatusOk           = Color(hex: 0x15803D)
}

// MARK: - Hero gradients (time-of-day variants)
enum HeroPalette {
    case morning, midday, evening, night, weekend

    var stops: [Color] {
        switch self {
        case .morning:
            return [Color(hex: 0x1E3A5F), Color(hex: 0x2D5A8A), Color(hex: 0x3A6FA8)]
        case .midday:
            return [Color(hex: 0x475569), Color(hex: 0x64748B)]
        case .evening:
            return [Color(hex: 0x422560), Color(hex: 0x7A3B5C), Color(hex: 0xC66848)]
        case .night:
            return [Color(hex: 0x0A0E1A), Color(hex: 0x1A1F2E)]
        case .weekend:
            return [Color(hex: 0x2D4A3E), Color(hex: 0x4A6F5A)]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Decorative orb tint that sits behind the gradient.
    var orbTint: Color {
        switch self {
        case .morning:  return Color(red: 1.0, green: 0.82, blue: 0.59).opacity(0.08)
        case .midday:   return Color.white.opacity(0.06)
        case .evening:  return Color(red: 1.0, green: 0.71, blue: 0.47).opacity(0.10)
        case .night:    return Color(red: 0.39, green: 0.55, blue: 1.0).opacity(0.05)
        case .weekend:  return Color(red: 0.71, green: 1.0, blue: 0.78).opacity(0.08)
        }
    }
}

// MARK: - CM spacing & radius tokens
enum CMSpacing {
    static let cardPadding: CGFloat = 14
    static let cardGap: CGFloat = 10
    static let sectionGap: CGFloat = 18
    static let screenHorizontal: CGFloat = 16
    static let rowGap: CGFloat = 10
}

enum CMRadius {
    static let card: CGFloat = 16
    static let pill: CGFloat = 10
    static let searchBar: CGFloat = 14
    static let chip: CGFloat = 14
    static let tabBar: CGFloat = 28
    static let statusPill: CGFloat = 12
}
