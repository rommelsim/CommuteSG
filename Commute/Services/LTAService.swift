import Foundation

enum LTAError: LocalizedError {
    case missingKey
    case badStatus(Int)
    case decoding(Error)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .missingKey:        "LTA API key not configured. Check Secrets.xcconfig."
        case .badStatus(let s):  "LTA API returned HTTP \(s)."
        case .decoding(let e):   "Could not parse LTA response: \(e.localizedDescription)"
        case .network(let e):    "Network error: \(e.localizedDescription)"
        }
    }
}

actor LTAService {
    static let shared = LTAService()

    private let baseURL = URL(string: "https://datamall2.mytransport.sg/ltaodataservice")!
    private let session: URLSession
    private let arrivalCacheTTL: TimeInterval     = 30
    private let alertCacheTTL: TimeInterval       = 60
    private let crowdCacheTTL: TimeInterval       = 60 * 5   // PCDRealTime updates every 10 min
    private let facilitiesCacheTTL: TimeInterval  = 60 * 30  // Ad-hoc updates

    private struct CachedArrivals { let value: [BusArrival]; let at: Date }
    private var arrivalsCache: [String: CachedArrivals] = [:]

    private struct CachedAlerts { let value: [TransitAlert]; let raw: LTATrainAlertValue?; let at: Date }
    private var alertsCache: CachedAlerts?

    private struct CachedCrowd { let value: [LTAStationCrowd]; let at: Date }
    private var crowdCache: [String: CachedCrowd] = [:]

    private struct CachedFacilities { let value: [LTAFacilityMaintenance]; let at: Date }
    private var facilitiesCache: CachedFacilities?

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = 8
            cfg.timeoutIntervalForResource = 12
            cfg.waitsForConnectivity = false
            self.session = URLSession(configuration: cfg)
        }
    }

    // MARK: - Public

    func busArrivals(at busStopCode: String, serviceNo: String? = nil, force: Bool = false) async throws -> [BusArrival] {
        let cacheKey = serviceNo.map { "\(busStopCode)|\($0)" } ?? busStopCode
        if !force, let cached = arrivalsCache[cacheKey],
           Date().timeIntervalSince(cached.at) < arrivalCacheTTL {
            return cached.value
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("v3/BusArrival"), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "BusStopCode", value: busStopCode)]
        if let serviceNo { items.append(URLQueryItem(name: "ServiceNo", value: serviceNo)) }
        components.queryItems = items
        let url = components.url!

        let response: LTABusArrivalResponse = try await get(url: url)
        let arrivals = response.services.map { $0.toBusArrival() }
        arrivalsCache[cacheKey] = CachedArrivals(value: arrivals, at: Date())
        return arrivals
    }

    func busRoutesPage(skip: Int) async throws -> [LTABusRoute] {
        var components = URLComponents(url: baseURL.appendingPathComponent("BusRoutes"), resolvingAgainstBaseURL: false)!
        if skip > 0 {
            components.queryItems = [URLQueryItem(name: "$skip", value: String(skip))]
        }
        let url = components.url!
        let response: LTABusRoutesResponse = try await get(url: url)
        return response.value
    }

    /// Forward-looking crowd forecast per station for the requested
    /// line. LTA returns 30-min slots over the next ~90 minutes;
    /// `StationCrowdService` collapses these into hour buckets for the
    /// browser sheet's timeline.
    func stationCrowdForecast(line: String, force: Bool = false) async throws -> [LTAStationCrowdForecast] {
        var components = URLComponents(url: baseURL.appendingPathComponent("PCDRealTimeForecast"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "TrainLine", value: line)]
        let url = components.url!
        let response: LTAStationCrowdForecastResponse = try await get(url: url)
        return response.value.flatMap(\.stations)
    }

    func stationCrowd(line: String, force: Bool = false) async throws -> [LTAStationCrowd] {
        let now = Date()
        if !force, let cached = crowdCache[line],
           now.timeIntervalSince(cached.at) < crowdCacheTTL {
            return cached.value
        }
        var components = URLComponents(url: baseURL.appendingPathComponent("PCDRealTime"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "TrainLine", value: line)]
        let url = components.url!
        let response: LTAStationCrowdResponse = try await get(url: url)
        crowdCache[line] = CachedCrowd(value: response.value, at: now)
        return response.value
    }

    func facilitiesMaintenance(force: Bool = false) async throws -> [LTAFacilityMaintenance] {
        if !force, let cached = facilitiesCache,
           Date().timeIntervalSince(cached.at) < facilitiesCacheTTL {
            return cached.value
        }
        let url = baseURL.appendingPathComponent("v2/FacilitiesMaintenance")
        let response: LTAFacilitiesMaintenanceResponse = try await get(url: url)
        facilitiesCache = CachedFacilities(value: response.value, at: Date())
        return response.value
    }

    func busStopsPage(skip: Int) async throws -> [LTABusStop] {
        var components = URLComponents(url: baseURL.appendingPathComponent("BusStops"), resolvingAgainstBaseURL: false)!
        if skip > 0 {
            components.queryItems = [URLQueryItem(name: "$skip", value: String(skip))]
        }
        let url = components.url!
        let response: LTABusStopsResponse = try await get(url: url)
        return response.value
    }

    func trainAlerts(force: Bool = false) async throws -> LTATrainAlertValue {
        if !force, let cached = alertsCache, let raw = cached.raw,
           Date().timeIntervalSince(cached.at) < alertCacheTTL {
            return raw
        }
        let url = baseURL.appendingPathComponent("TrainServiceAlerts")
        let response: LTATrainAlertResponse = try await get(url: url)
        let mapped = response.value.toTransitAlerts()
        alertsCache = CachedAlerts(value: mapped, raw: response.value, at: Date())
        return response.value
    }

    func trainAlertsAsTransitAlerts(force: Bool = false) async throws -> [TransitAlert] {
        _ = try await trainAlerts(force: force)
        return alertsCache?.value ?? []
    }

    // MARK: - Plumbing

    private func get<T: Decodable>(url: URL) async throws -> T {
        let key = Secrets.ltaAPIKey
        guard !key.isEmpty else { throw LTAError.missingKey }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(key, forHTTPHeaderField: "AccountKey")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LTAError.network(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw LTAError.badStatus(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw LTAError.decoding(error)
        }
    }
}

// MARK: - Mappers

private extension LTABusService {
    func toBusArrival() -> BusArrival {
        let next = nextBus.toDetails()
        let following = nextBus2.toDetails()
        let coord = nextBus.coordinateDouble
        return BusArrival(
            serviceNo: serviceNo,
            destination: destinationLabel,
            destinationCode: nextBus.destinationCode.isEmpty ? nil : nextBus.destinationCode,
            operatorName: `operator`,
            nextArrivalAt: next.arrivalAt,
            nextArrivalCrowd: next.crowd,
            nextArrivalType: next.type,
            nextArrivalIsScheduled: next.isScheduled,
            nextArrivalLatitude: coord?.lat,
            nextArrivalLongitude: coord?.lon,
            followingArrivalAt: following.arrivalAt,
            followingArrivalCrowd: following.crowd,
            followingArrivalType: following.type,
            followingArrivalIsScheduled: following.isScheduled
        )
    }

    var destinationLabel: String {
        let code = nextBus.destinationCode
        return code.isEmpty ? "" : "→ \(code)"
    }
}

private extension LTANextBus {
    func toDetails() -> (arrivalAt: Date?, crowd: CrowdLevel, type: BusType, isScheduled: Bool) {
        let crowd: CrowdLevel = {
            switch load {
            case "SEA": .seats
            case "SDA": .standing
            case "LSD": .limited
            default:    .unknown
            }
        }()
        let busType = BusType(rawValue: self.type) ?? .unknown
        let arrivalAt = parseArrival(estimatedArrival)
        let isScheduled = (monitored == 0)
        return (arrivalAt, crowd, busType, isScheduled)
    }

    private func parseArrival(_ iso: String) -> Date? {
        guard !iso.isEmpty else { return nil }
        return ISO8601DateFormatter.ltaWithFractional.date(from: iso)
            ?? ISO8601DateFormatter.ltaPlain.date(from: iso)
    }
}

private extension ISO8601DateFormatter {
    static let ltaWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let ltaPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

private extension LTATrainAlertValue {
    func toTransitAlerts() -> [TransitAlert] {
        if status == 1 {
            return [
                TransitAlert(
                    severity: .success,
                    kind: .mrt,
                    tag: "All clear",
                    title: "All MRT lines running normally",
                    body: nil,
                    timeLabel: "Now"
                )
            ]
        }

        return affectedSegments.map { seg in
            let line = seg.line.uppercased()
            let body = "Stations affected: \(seg.stations). \(message.first?.content ?? "")"
            return TransitAlert(
                severity: .danger,
                kind: .mrt,
                tag: "Major delay",
                title: "\(line) Line",
                body: body.trimmingCharacters(in: .whitespacesAndNewlines),
                timeLabel: "Now"
            )
        }
    }
}
