import SwiftUI

enum MRTLine: String, CaseIterable, Codable, Hashable {
    case ew, ns, ne, cc, dt, te, ce

    var code: String {
        switch self {
        case .ew: "EW"
        case .ns: "NS"
        case .ne: "NE"
        case .cc: "CC"
        case .dt: "DT"
        case .te: "TE"
        case .ce: "CE"
        }
    }

    var fullName: String {
        switch self {
        case .ew: "East-West Line"
        case .ns: "North-South Line"
        case .ne: "North-East Line"
        case .cc: "Circle Line"
        case .dt: "Downtown Line"
        case .te: "Thomson-East Coast Line"
        case .ce: "Changi Extension"
        }
    }

    var background: Color {
        switch self {
        case .ew: Color(hex: 0x009645)
        case .ns: Color(hex: 0xD42E12)
        case .ne: Color(hex: 0x9900AA)
        case .cc: Color(hex: 0xFA9E0D)
        case .dt: Color(hex: 0x005EC4)
        case .te: Color(hex: 0x9D5918)
        case .ce: Color(hex: 0xFA9E0D)
        }
    }

    var foreground: Color {
        switch self {
        case .cc, .ce: Color(hex: 0x4A1B0C)
        default: .white
        }
    }

    /// LTA DataMall train-line code used by PCDRealTime / TrainServiceAlerts
    var ltaTrainLine: String {
        switch self {
        case .ew: "EWL"
        case .ns: "NSL"
        case .ne: "NEL"
        case .cc: "CCL"
        case .dt: "DTL"
        case .te: "TEL"
        case .ce: "CGL"
        }
    }
}
