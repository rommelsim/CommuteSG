import SwiftUI

/// Scale: 4 / 8 / 12 / 16 / 24 / 28 / 32. Two named off-scale values are kept
/// for spec-mandated specific gaps that don't fit the scale (`s10`, `s20`).
enum Spacing {
    // Scale
    static let s4: CGFloat  = 4
    static let s8: CGFloat  = 8
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s24: CGFloat = 24
    static let s28: CGFloat = 28
    static let s32: CGFloat = 32

    // Spec-explicit, between-tier values
    static let s10: CGFloat = 10
    static let s20: CGFloat = 20

    // Semantic aliases (kept for callers across the app)
    static let screen: CGFloat          = s24   // outer horizontal gutter
    static let cardInner: CGFloat       = s16   // card internal padding
    static let cardInnerSmall: CGFloat  = s12
    static let cardInnerTight: CGFloat  = s8
    static let cardGap: CGFloat         = s12   // between sibling cards
    static let sectionGap: CGFloat      = s28   // between sections

    // Semantic typography aliases for clarity
    static let xs: CGFloat = s4
    static let s: CGFloat  = s8
    static let m: CGFloat  = s16
    static let l: CGFloat  = s24
}

enum Radius {
    static let card: CGFloat        = 12   // MRT card / generic card
    static let large: CGFloat       = 16
    static let small: CGFloat       = 8
    static let pill: CGFloat        = 20
    static let chip: CGFloat        = 5    // line-code badge
    static let shortcutCard: CGFloat = 14
    static let searchBar: CGFloat   = 12
}
