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
