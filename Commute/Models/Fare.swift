import Foundation
import CoreLocation

// MARK: - Public-facing fare types

enum FareCategory: String, CaseIterable, Hashable {
    case adult = "adult"
    case seniorCitizen = "senior_citizen"
    case student = "student"
    case personsWithDisabilities = "persons_with_disabilities"
    case workfare = "workfare"

    var label: String {
        switch self {
        case .adult:                   "Adult"
        case .seniorCitizen:           "Senior"
        case .student:                 "Student"
        case .personsWithDisabilities: "PWD"
        case .workfare:                "Workfare"
        }
    }
}

enum FareMode: String, CaseIterable, Hashable {
    case mrtLrt = "mrt_lrt"
    case trunkBus = "trunk_bus"
    case feederBus = "feeder_bus"
    case expressBus = "express_bus"

    var label: String {
        switch self {
        case .mrtLrt:    "MRT/LRT"
        case .trunkBus:  "Trunk bus"
        case .feederBus: "Feeder bus"
        case .expressBus: "Express bus"
        }
    }

    var symbol: String {
        switch self {
        case .mrtLrt:    "tram.fill"
        case .trunkBus:  "bus.fill"
        case .feederBus: "bus"
        case .expressBus: "bolt.fill"
        }
    }

    /// Whether cash payment is accepted on this mode. MRT/LRT is card-only.
    var acceptsCash: Bool {
        self != .mrtLrt
    }
}

enum FarePayment: String, CaseIterable, Hashable {
    case card, cash

    var label: String {
        switch self {
        case .card: "Card / SimplyGo"
        case .cash: "Cash"
        }
    }
}

struct FareLeg: Hashable {
    let mode: FareMode
    let distanceKm: Double
    let boardTime: Date
    let alightTime: Date
}

// MARK: - Endpoint for the fare-calculator UI

/// A coordinate-bearing point the user picked as the start or end of a fare
/// calculation. Stored with lat/lng so it's `Hashable` and `Codable`.
struct FareEndpoint: Identifiable, Hashable, Codable {
    enum Kind: String, Codable, Hashable { case mrt, bus }

    let id: String
    let label: String
    let secondary: String?
    let latitude: Double
    let longitude: Double
    let kind: Kind
}

extension FareEndpoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    /// Build an endpoint from an MRT station, looking up the coordinate from
    /// the station catalogue. Returns nil if the catalogue has no coordinate
    /// for the station code.
    static func make(from mrt: MRTStation) -> FareEndpoint? {
        guard let coord = MRTStationsRepository.shared.coordinate(for: mrt.id) else {
            return nil
        }
        return FareEndpoint(
            id: "mrt-\(mrt.id)",
            label: "\(mrt.name) MRT",
            secondary: "\(mrt.id) · \(mrt.line.fullName)",
            latitude: coord.latitude,
            longitude: coord.longitude,
            kind: .mrt
        )
    }

    /// Build an endpoint from a bus stop. Returns nil if the stop has no
    /// coordinate (some legacy stops in the catalogue lack one).
    static func make(from stop: BusStop) -> FareEndpoint? {
        guard let coord = stop.coordinate else { return nil }
        return FareEndpoint(
            id: "bus-\(stop.id)",
            label: stop.name,
            secondary: "\(stop.id) · \(stop.road)",
            latitude: coord.latitude,
            longitude: coord.longitude,
            kind: .bus
        )
    }
}

// MARK: - Decoded JSON shape (`fares.json`)

struct FareData: Decodable {
    let metadata: Metadata
    let distanceBands: [DistanceBand]
    let modes: Modes

    enum CodingKeys: String, CodingKey {
        case metadata
        case distanceBands = "distance_bands"
        case modes
    }

    struct Metadata: Decodable {
        let effectiveDate: String
        let currency: String

        enum CodingKeys: String, CodingKey {
            case effectiveDate = "effective_date"
            case currency
        }
    }

    struct DistanceBand: Decodable, Hashable {
        let id: Int
        let label: String
        let minKm: Double
        /// `null` for the cap band ("Over 40.2 km").
        let maxKm: Double?

        enum CodingKeys: String, CodingKey {
            case id, label
            case minKm = "min_km"
            case maxKm = "max_km"
        }
    }

    struct Modes: Decodable {
        let trunkBus: TrunkBus
        let mrtLrt: MRTLRT
        let feederBus: FeederBus
        let expressBus: ExpressBus

        enum CodingKeys: String, CodingKey {
            case trunkBus = "trunk_bus"
            case mrtLrt = "mrt_lrt"
            case feederBus = "feeder_bus"
            case expressBus = "express_bus"
        }
    }

    struct TrunkBus: Decodable {
        let cardFaresByBand: [String: [String: Int]]
        let cashFaresByBand: [String: [String: Int]]

        enum CodingKeys: String, CodingKey {
            case cardFaresByBand = "card_fares_by_band"
            case cashFaresByBand = "cash_fares_by_band"
        }
    }

    struct MRTLRT: Decodable {
        let faresByBand: FaresByBand

        enum CodingKeys: String, CodingKey {
            case faresByBand = "fares_by_band"
        }

        struct FaresByBand: Decodable {
            let morningPrePeak: [String: [String: Int]]
            let standard: [String: [String: Int]]

            enum CodingKeys: String, CodingKey {
                case morningPrePeak = "morning_pre_peak"
                case standard
            }
        }
    }

    struct FeederBus: Decodable {
        let cardFlatFare: [String: Int]
        let cashFlatFare: [String: Int]

        enum CodingKeys: String, CodingKey {
            case cardFlatFare = "card_flat_fare"
            case cashFlatFare = "cash_flat_fare"
        }
    }

    struct ExpressBus: Decodable {
        /// Each band entry has keys like `adult_card`, `senior_citizen_card`,
        /// …, plus a single `cash_all_categories`.
        let faresByBand: [String: [String: Int]]

        enum CodingKeys: String, CodingKey {
            case faresByBand = "fares_by_band"
        }
    }
}
