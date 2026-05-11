import Foundation
import CoreLocation

// MARK: - Adapters: data-layer models → CM display-layer view models
// One-way mapping. The new design-language views (`MRTStationsView`,
// `BusStopsView`) take CM-prefixed types so we don't entangle their layout
// with the existing `BusStop` / `MRTStation` / `BusArrival` shapes.

enum StopsAdapters {
    /// 80 m/min is a standard walking pace; round up so 80 m = 1 min, 81 m = 2 min.
    static func walkMinutes(forMeters meters: Int) -> Int {
        max(1, Int(ceil(Double(meters) / 80.0)))
    }

    /// Map an existing `MRTStation` → CM display model. Live arrivals are not
    /// populated here — tap into the station detail sheet for those.
    static func make(from station: MRTStation) -> CMMRTStation {
        let meters = station.distanceMeters ?? 0
        return CMMRTStation(
            name: station.name,
            codes: codes(for: station),
            walkMinutes: walkMinutes(forMeters: meters),
            walkMeters: meters,
            arrivalsByLine: [:]
        )
    }

    /// All MRT codes that meet at this physical station (primary + interchanges).
    /// Looks up each interchange line's code by station name; falls back to a
    /// "?"-suffixed prefix if no match exists in the repository.
    static func codes(for station: MRTStation) -> [String] {
        [station.id] + station.interchangeLines.map { line in
            let match = MRTStationsRepository.shared.stations.first {
                $0.line == line && $0.name == station.name
            }
            return match?.id ?? "\(line.code)?"
        }
    }

    /// Map an existing bus stop + its arrivals → CM display model.
    @MainActor
    static func make(from stop: BusStop, arrivals: [BusArrival]) -> CMBusStop {
        let meters = stop.distanceMeters ?? 0
        let services = arrivals
            .sorted { ($0.nextArrivalMinutes ?? .max) < ($1.nextArrivalMinutes ?? .max) }
            .map { arr in
                CMBusService(
                    number: arr.serviceNo,
                    destination: destinationLabel(for: arr),
                    nextMinutes: arr.nextArrivalMinutes,
                    followingMinutes: arr.followingArrivalMinutes
                )
            }
        return CMBusStop(
            name: stop.name,
            code: stop.id,
            walkMinutes: walkMinutes(forMeters: meters),
            walkMeters: meters,
            services: services,
            hasLiveData: !services.isEmpty
        )
    }

    /// Resolve an LTA destination code to a stop name when possible. Falls
    /// back to the raw code (e.g. "11379") if the stops dataset hasn't loaded
    /// yet or the code isn't in the catalogue.
    @MainActor
    static func destinationLabel(for arrival: BusArrival) -> String {
        if let code = arrival.destinationCode,
           let name = BusStopNameCache.shared.name(forCode: code) {
            return name
        }
        return arrival.destinationCode ?? ""
    }
}

// MARK: - Repository helper: nearest N MRT stations
extension MRTStationsRepository {
    /// Returns the N MRT stations nearest the given location, sorted ascending,
    /// with `distanceMeters` populated. Mirrors `BusStopsRepository.nearest(to:count:)`.
    func nearest(to location: CLLocation, count: Int) -> [MRTStation] {
        stations
            .compactMap { station -> (MRTStation, CLLocationDistance)? in
                guard let c = coordinate(for: station.id) else { return nil }
                let d = location.distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude))
                return (station, d)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(count)
            .map { entry in
                MRTStation(
                    id: entry.0.id, name: entry.0.name, line: entry.0.line,
                    interchangeLines: entry.0.interchangeLines, distanceMeters: Int(entry.1)
                )
            }
    }
}
