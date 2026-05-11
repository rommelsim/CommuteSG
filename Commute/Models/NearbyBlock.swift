import Foundation
import CoreTransferable

enum NearbyBlock: String, CaseIterable, Codable, Identifiable, Hashable, Transferable {
    case mrt, busStops

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mrt:      "MRT stations"
        case .busStops: "Bus stops"
        }
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .text)
    }
}
