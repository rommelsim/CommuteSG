import Foundation
import CoreLocation

final class MockDataService {
    static let shared = MockDataService()

    // MARK: - Bus stops near Bedok

    private let blk416 = BusStop(
        id: "84009",
        name: "Blk 416",
        road: "Bedok Nth Rd",
        distanceMeters: 80,
        coordinate: CLLocationCoordinate2D(latitude: 1.3296, longitude: 103.9305)
    )

    private let bedokTownPark = BusStop(
        id: "84029",
        name: "Bedok Town Park",
        road: "Bedok Nth St 3",
        distanceMeters: 220,
        coordinate: CLLocationCoordinate2D(latitude: 1.3308, longitude: 103.9298)
    )

    func nearbyStopsSeed() -> [(stop: BusStop, fallback: [BusArrival])] {
        [
            (blk416, blk416FallbackArrivals),
            (bedokTownPark, bedokTownParkFallbackArrivals)
        ]
    }

    func nearbyStopsFallback() -> [HomeViewModel.BusStopWithArrivals] {
        [
            .init(stop: blk416, arrivals: blk416FallbackArrivals),
            .init(stop: bedokTownPark, arrivals: bedokTownParkFallbackArrivals)
        ]
    }

    private var blk416FallbackArrivals: [BusArrival] {
        // Tuned to demonstrate that pill colour encodes *crowd*, not arrival time:
        // the closest bus (2 min) is RED (packed), while the next-closest (3 min)
        // is GREEN (seats) — picking by colour, not time, gets you a seat.
        [
            mockArrival(service: "2",  dest: "→ Changi Village", nextMin: 2,  nextCrowd: .limited,  nextType: .singleDeck, followMin: 14, followCrowd: .standing, followType: .doubleDeck),
            mockArrival(service: "14", dest: "→ Bedok Int.",     nextMin: 3,  nextCrowd: .seats,    nextType: .doubleDeck, followMin: 11, followCrowd: .standing, followType: .doubleDeck),
            mockArrival(service: "36", dest: "→ Tomlinson Rd",   nextMin: 7,  nextCrowd: .standing, nextType: .singleDeck, followMin: 19, followCrowd: .seats,    followType: .singleDeck),
            mockArrival(service: "5",  dest: "→ Marina Centre",  nextMin: 9,  nextCrowd: .seats,    nextType: .singleDeck, followMin: 22, followCrowd: .seats,    followType: .singleDeck)
        ]
    }

    private var bedokTownParkFallbackArrivals: [BusArrival] {
        // Includes one approximate (scheduled) arrival → CrowdLevel.unknown
        // so the neutral grey pill state is visible in the demo.
        [
            mockArrival(service: "15", dest: "→ Pasir Ris", nextMin: 4,  nextCrowd: .standing, nextType: .doubleDeck, followMin: 16, followCrowd: .seats,   followType: .singleDeck),
            mockArrival(service: "22", dest: "→ Tampines",  nextMin: 11, nextCrowd: .unknown,  nextType: .singleDeck, followMin: 24, followCrowd: .unknown, followType: .singleDeck, scheduled: true)
        ]
    }

    private func mockArrival(
        service: String, dest: String,
        nextMin: Int, nextCrowd: CrowdLevel, nextType: BusType,
        followMin: Int, followCrowd: CrowdLevel, followType: BusType,
        scheduled: Bool = false
    ) -> BusArrival {
        BusArrival(
            serviceNo: service, destination: dest, destinationCode: nil,
            operatorName: "SBS",
            nextArrivalAt: Date().addingTimeInterval(TimeInterval(nextMin) * 60),
            nextArrivalCrowd: nextCrowd, nextArrivalType: nextType,
            nextArrivalIsScheduled: scheduled,
            nextArrivalLatitude: nil, nextArrivalLongitude: nil,
            followingArrivalAt: Date().addingTimeInterval(TimeInterval(followMin) * 60),
            followingArrivalCrowd: followCrowd, followingArrivalType: followType,
            followingArrivalIsScheduled: scheduled
        )
    }

    // MARK: - Plan journey

    /// Mock journey planner that uses the real MRT station catalogue, real
    /// LTA coordinates, and the user's actual location (when available) to
    /// generate plausible routes. The destination's real MRT line is used
    /// where applicable; durations are derived from great-circle distance
    /// (~30 km/h MRT, ~20 km/h bus, ~5 km/h walk). LTA's DataMall has no
    /// journey-planning endpoint and OneMap requires an API key, so the
    /// numbers are still approximations — but lines and rough times are now
    /// anchored to reality, not a string hash.
    func journeyOptions(
        from: String,
        to: String,
        originHint: CLLocationCoordinate2D? = nil,
        destinationHint: CLLocationCoordinate2D? = nil
    ) -> [JourneyOption] {
        let mrtRepo = MRTStationsRepository.shared

        let originStation = Self.findStation(matching: from, in: mrtRepo.stations)
        let destStation = Self.findStation(matching: to, in: mrtRepo.stations)

        // Origin coordinate: caller-supplied GPS hint, matched station coord, or Clementi fallback.
        let originCoord = Self.resolveOrigin(
            input: from,
            matched: originStation,
            originHint: originHint,
            mrtRepo: mrtRepo
        )
        // Destination coordinate: matched station, geocoded hint, or Marina Bay fallback.
        let destCoord: CLLocationCoordinate2D = {
            if let s = destStation, let c = mrtRepo.coordinate(for: s.id) { return c }
            if let hint = destinationHint { return hint }
            return CLLocationCoordinate2D(latitude: 1.27637, longitude: 103.85497)
        }()

        let originLoc = CLLocation(latitude: originCoord.latitude, longitude: originCoord.longitude)
        let destLoc = CLLocation(latitude: destCoord.latitude, longitude: destCoord.longitude)
        let totalKm = max(0.5, originLoc.distance(from: destLoc) / 1000)

        // Lines: prefer the destination's actual line. For non-MRT
        // destinations, fall back to the line of the nearest station to the
        // destination coordinate. Same for origin.
        let destLine = destStation?.line
            ?? mrtRepo.nearest(to: destLoc)?.line
            ?? .ew
        let originLine = originStation?.line
            ?? mrtRepo.nearest(to: originLoc)?.line
            ?? destLine
        let needsTransfer = originLine != destLine

        // Durations: walking ~5 km/h (12 min/km), MRT ~30 km/h (2 min/km),
        // bus ~20 km/h (3 min/km) — Singapore averages with stops. A transfer
        // adds ~4 min of platform-change time.
        let walkToMRT = originStation == nil ? 4 : 1     // 1 min if already at MRT, else ~4
        let walkFromMRT = destStation == nil ? 4 : 1
        let baseMRT = max(6, Int((totalKm * 2).rounded()))
        let mrtRide = baseMRT + (originLine != destLine ? 4 : 0)
        let busRide = max(8, Int((totalKm * 3).rounded()))

        // Stable hash for per-pair variety (bus number selection, crowd, etc.)
        let key = "\(from.lowercased())→\(to.lowercased())"
        let seed = key.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let busServices = ["12", "14", "36", "65", "75", "143", "147", "165", "196", "857"]
        let crowds: [CrowdLevel] = [.seats, .standing, .seats, .limited, .seats, .standing]

        // -- Route 1: MRT-heavy (fastest) --
        var mrtSegments: [JourneyOption.Segment] = [.walk(minutes: walkToMRT)]
        if needsTransfer {
            let half = mrtRide / 2
            mrtSegments.append(.mrt(originLine, minutes: half))
            mrtSegments.append(.mrt(destLine, minutes: max(4, mrtRide - half)))
        } else {
            mrtSegments.append(.mrt(destLine, minutes: mrtRide))
        }
        mrtSegments.append(.walk(minutes: walkFromMRT))
        let mrtFare = Self.estimateFare(km: totalKm, kind: .mrt)
        let fastest = JourneyOption(
            durationMinutes: walkToMRT + mrtRide + walkFromMRT,
            walkMinutes: walkToMRT + walkFromMRT,
            fareSGD: mrtFare,
            segments: mrtSegments,
            crowd: crowds[seed % crowds.count],
            leavesInMinutes: 2 + (seed % 4),
            isBest: true
        )

        // -- Route 2: Bus + MRT (mixed) --
        let busLeg = max(8, Int((totalKm * 0.4 * 3).rounded()))
        let mrtLeg = max(6, mrtRide - 2)
        let mixed = JourneyOption(
            durationMinutes: 2 + busLeg + mrtLeg + 2,
            walkMinutes: 4,
            fareSGD: Self.estimateFare(km: totalKm, kind: .mixed),
            segments: [
                .walk(minutes: 2),
                .bus(serviceNo: busServices[seed % busServices.count], minutes: busLeg),
                .mrt(destLine, minutes: mrtLeg),
                .walk(minutes: 2)
            ],
            crowd: .standing,
            leavesInMinutes: 5 + (seed % 3),
            isBest: false
        )

        // -- Route 3: Direct bus (cheapest) --
        let cheapest = JourneyOption(
            durationMinutes: 2 + busRide + 1,
            walkMinutes: 3,
            fareSGD: Self.estimateFare(km: totalKm, kind: .bus),
            segments: [
                .walk(minutes: 2),
                .bus(serviceNo: busServices[(seed / 7) % busServices.count], minutes: busRide),
                .walk(minutes: 1)
            ],
            crowd: crowds[(seed / 11) % crowds.count],
            leavesInMinutes: 7 + (seed % 5),
            isBest: false
        )

        return [fastest, mixed, cheapest]
    }

    private enum FareKind { case mrt, mixed, bus }

    /// Approximation of Singapore's distance-based fare table.
    /// Cap at ~$2.30 single trip — long bus rides are cheaper than MRT.
    private static func estimateFare(km: Double, kind: FareKind) -> Double {
        let base: Double
        switch kind {
        case .mrt:   base = min(2.30, 0.99 + km * 0.07)
        case .mixed: base = min(2.20, 0.95 + km * 0.06)
        case .bus:   base = min(2.10, 0.85 + km * 0.05)
        }
        return (base * 100).rounded() / 100
    }

    /// Match a free-text query to an MRT station by name. Tolerates "MRT" /
    /// "Station" suffixes and matches in either direction so "Marina Bay
    /// Sands" maps to the Marina Bay station, and "outram" maps to "Outram
    /// Park". Avoids matching "current location" or empty strings.
    private static func findStation(matching query: String, in stations: [MRTStation]) -> MRTStation? {
        let cleaned = query
            .lowercased()
            .replacingOccurrences(of: " mrt", with: "")
            .replacingOccurrences(of: " station", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, cleaned != "current location" else { return nil }
        if let exact = stations.first(where: { $0.name.lowercased() == cleaned }) {
            return exact
        }
        // Station name fully contained in query, e.g. "Marina Bay Sands" → Marina Bay.
        // Pick the longest such match so "Marina Bay Sands" prefers "Marina Bay" over "Bay".
        let containedInQuery = stations
            .filter { cleaned.contains($0.name.lowercased()) }
            .sorted { $0.name.count > $1.name.count }
        if let match = containedInQuery.first { return match }
        // Query contained in station name, e.g. "outram" → "Outram Park".
        return stations.first { $0.name.lowercased().contains(cleaned) }
    }

    private static func resolveOrigin(
        input: String,
        matched: MRTStation?,
        originHint: CLLocationCoordinate2D?,
        mrtRepo: MRTStationsRepository
    ) -> CLLocationCoordinate2D {
        // MRT name match wins — picking "Bedok MRT" should anchor to the
        // station even if a stale GPS hint is also present.
        if let s = matched, let c = mrtRepo.coordinate(for: s.id) {
            return c
        }
        // Otherwise honor the caller's coordinate hint. This covers two cases:
        // "Current location" (hint = GPS) and any geocoded address pick
        // (hint = postal-code / road coord). Without this the planner
        // collapses every non-MRT origin to Clementi, making all routes look
        // identical regardless of what the user typed.
        if let hint = originHint {
            return hint
        }
        return CLLocationCoordinate2D(latitude: 1.31495, longitude: 103.76506)
    }

    // MARK: - Live tracking timeline

    func upcomingStops(forService _: String) -> [(name: String, etaMin: Int)] {
        [
            ("Bedok Sth Ave 3", 3),
            ("Tanah Merah", 7),
            ("Simei", 12),
            ("Tampines", 18)
        ]
    }

    // MARK: - Alerts (mock — bus + for-you alerts)

    func alerts() -> [TransitAlert] {
        [
            TransitAlert(
                severity: .danger, kind: .mrt,
                tag: "Major delay", title: "East-West Line",
                body: "Delays of up to 15 min between Bugis and Tanah Merah. Service recovery in progress.",
                timeLabel: "Now"
            ),
            TransitAlert(
                severity: .warning, kind: .bus,
                tag: "Schedule change", title: "Bus 14 detour",
                body: "Diverted via Marine Parade Rd until 11pm tonight.",
                timeLabel: "12 min"
            ),
            TransitAlert(
                severity: .info, kind: .forYou,
                tag: "For you", title: "Free off-peak ride",
                body: "Tap in before 7:30am tomorrow on the NEL for a free trip.",
                timeLabel: "2h ago"
            ),
            TransitAlert(
                severity: .success, kind: .mrt,
                tag: "Resolved", title: "Circle Line lift at Bayfront restored.",
                body: nil,
                timeLabel: "3h ago"
            )
        ]
    }

}
