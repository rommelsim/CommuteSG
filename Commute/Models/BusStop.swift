import Foundation
import CoreLocation

struct BusStop: Identifiable, Hashable {
    let id: String              // bus stop code (e.g. "84009")
    let name: String
    let road: String
    let distanceMeters: Int?
    let coordinate: CLLocationCoordinate2D?

    static func == (lhs: BusStop, rhs: BusStop) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
