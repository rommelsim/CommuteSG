import Foundation
import CoreLocation

/// Static, in-app catalogue of Singapore MRT stations with coordinates.
/// LTA's DataMall API does not expose train stations, so we ship a curated list.
/// Coverage: all heavy-rail (MRT) lines our `MRTLine` enum supports.
struct MRTStationsRepository {
    static let shared = MRTStationsRepository()

    let stations: [MRTStation]

    init() {
        self.stations = Self.allStations
    }

    /// Returns the MRT station nearest to a given location, with `distanceMeters` populated.
    func nearest(to location: CLLocation) -> MRTStation? {
        stations
            .map { station -> (MRTStation, CLLocationDistance) in
                let coord = Self.coordinate(for: station.id)
                let dist = location.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
                return (station, dist)
            }
            .min(by: { $0.1 < $1.1 })
            .map { entry -> MRTStation in
                MRTStation(
                    id: entry.0.id, name: entry.0.name, line: entry.0.line,
                    interchangeLines: entry.0.interchangeLines, distanceMeters: Int(entry.1)
                )
            }
    }

    func coordinate(for code: String) -> CLLocationCoordinate2D? {
        Self.coordinates[code]
    }

    func distance(from location: CLLocation, to code: String) -> CLLocationDistance? {
        guard let c = coordinate(for: code) else { return nil }
        return location.distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude))
    }

    /// Returns stations within ±`radius` of `current` on the same line, in numeric order.
    /// Always includes the current station; shorter at the ends of the line.
    func neighborhood(around current: MRTStation, radius: Int = 2) -> [(station: MRTStation, isCurrent: Bool)] {
        let sameLine = stations.filter { $0.line == current.line }
            .sorted { Self.numericPart($0.id) < Self.numericPart($1.id) }
        guard let idx = sameLine.firstIndex(where: { $0.id == current.id }) else { return [] }
        let lower = max(0, idx - radius)
        let upper = min(sameLine.count - 1, idx + radius)
        return sameLine[lower...upper].map { ($0, $0.id == current.id) }
    }

    /// Returns the two end stations (lowest and highest numeric ID) of a given line.
    func termini(for line: MRTLine) -> (toward: MRTStation, fromward: MRTStation)? {
        let onLine = stations.filter { $0.line == line }
            .sorted { Self.numericPart($0.id) < Self.numericPart($1.id) }
        guard let first = onLine.first, let last = onLine.last, first.id != last.id else { return nil }
        return (first, last)
    }

    private static func numericPart(_ code: String) -> Int {
        Int(code.filter(\.isNumber)) ?? 0
    }

    private static func coordinate(for code: String) -> CLLocationCoordinate2D {
        Self.coordinates[code] ?? CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198)
    }

    /// Coordinates keyed by station code. Sourced from public LTA station listings.
    private static let coordinates: [String: CLLocationCoordinate2D] = [
        // East-West Line (EWL)
        "EW1":  .init(latitude: 1.37257, longitude: 103.94921), // Pasir Ris
        "EW2":  .init(latitude: 1.35345, longitude: 103.94534), // Tampines
        "EW3":  .init(latitude: 1.34306, longitude: 103.95319), // Simei
        "EW4":  .init(latitude: 1.32743, longitude: 103.94656), // Tanah Merah
        "EW5":  .init(latitude: 1.32404, longitude: 103.93022), // Bedok
        "EW6":  .init(latitude: 1.32101, longitude: 103.91277), // Kembangan
        "EW7":  .init(latitude: 1.31972, longitude: 103.90305), // Eunos
        "EW8":  .init(latitude: 1.31813, longitude: 103.89263), // Paya Lebar
        "EW9":  .init(latitude: 1.31633, longitude: 103.88284), // Aljunied
        "EW10": .init(latitude: 1.31480, longitude: 103.87131), // Kallang
        "EW11": .init(latitude: 1.30727, longitude: 103.86303), // Lavender
        "EW12": .init(latitude: 1.30068, longitude: 103.85604), // Bugis
        "EW13": .init(latitude: 1.29314, longitude: 103.85230), // City Hall
        "EW14": .init(latitude: 1.28411, longitude: 103.85153), // Raffles Place
        "EW15": .init(latitude: 1.27636, longitude: 103.84592), // Tanjong Pagar
        "EW16": .init(latitude: 1.28041, longitude: 103.83926), // Outram Park
        "EW17": .init(latitude: 1.28649, longitude: 103.82689), // Tiong Bahru
        "EW18": .init(latitude: 1.28968, longitude: 103.81672), // Redhill
        "EW19": .init(latitude: 1.29475, longitude: 103.80606), // Queenstown
        "EW20": .init(latitude: 1.30240, longitude: 103.79827), // Commonwealth
        "EW21": .init(latitude: 1.30715, longitude: 103.79014), // Buona Vista
        "EW22": .init(latitude: 1.31132, longitude: 103.77847), // Dover
        "EW23": .init(latitude: 1.31527, longitude: 103.76452), // Clementi
        "EW24": .init(latitude: 1.33344, longitude: 103.74257), // Jurong East
        "EW25": .init(latitude: 1.34229, longitude: 103.73297), // Chinese Garden
        "EW26": .init(latitude: 1.34442, longitude: 103.72085), // Lakeside
        "EW27": .init(latitude: 1.33869, longitude: 103.70597), // Boon Lay
        "EW28": .init(latitude: 1.33761, longitude: 103.69727), // Pioneer
        "EW29": .init(latitude: 1.32717, longitude: 103.67828), // Joo Koon
        "EW30": .init(latitude: 1.32127, longitude: 103.66127), // Gul Circle
        "EW31": .init(latitude: 1.31479, longitude: 103.65621), // Tuas Crescent
        "EW32": .init(latitude: 1.30993, longitude: 103.64906), // Tuas West Road
        "EW33": .init(latitude: 1.31797, longitude: 103.63689), // Tuas Link

        // Changi Extension (CGL — our enum: .ce)
        "CG1":  .init(latitude: 1.31611, longitude: 103.96266), // Expo
        "CG2":  .init(latitude: 1.35733, longitude: 103.98826), // Changi Airport

        // North-South Line (NSL)
        "NS1":  .init(latitude: 1.33344, longitude: 103.74257), // Jurong East
        "NS2":  .init(latitude: 1.34906, longitude: 103.74959), // Bukit Batok
        "NS3":  .init(latitude: 1.35870, longitude: 103.75175), // Bukit Gombak
        "NS4":  .init(latitude: 1.38554, longitude: 103.74410), // Choa Chu Kang
        "NS5":  .init(latitude: 1.39729, longitude: 103.74738), // Yew Tee
        "NS7":  .init(latitude: 1.42513, longitude: 103.76199), // Kranji
        "NS8":  .init(latitude: 1.43266, longitude: 103.77419), // Marsiling
        "NS9":  .init(latitude: 1.43702, longitude: 103.78649), // Woodlands
        "NS10": .init(latitude: 1.44067, longitude: 103.80098), // Admiralty
        "NS11": .init(latitude: 1.44918, longitude: 103.82010), // Sembawang
        "NS13": .init(latitude: 1.42940, longitude: 103.83502), // Yishun
        "NS14": .init(latitude: 1.41715, longitude: 103.83299), // Khatib
        "NS15": .init(latitude: 1.38188, longitude: 103.84490), // Yio Chu Kang
        "NS16": .init(latitude: 1.36978, longitude: 103.84955), // Ang Mo Kio
        "NS17": .init(latitude: 1.35099, longitude: 103.84812), // Bishan
        "NS18": .init(latitude: 1.34044, longitude: 103.84697), // Braddell
        "NS19": .init(latitude: 1.33272, longitude: 103.84736), // Toa Payoh
        "NS20": .init(latitude: 1.32048, longitude: 103.84383), // Novena
        "NS21": .init(latitude: 1.31338, longitude: 103.83815), // Newton
        "NS22": .init(latitude: 1.30419, longitude: 103.83202), // Orchard
        "NS23": .init(latitude: 1.30048, longitude: 103.83870), // Somerset
        "NS24": .init(latitude: 1.29853, longitude: 103.84563), // Dhoby Ghaut
        "NS25": .init(latitude: 1.29314, longitude: 103.85230), // City Hall
        "NS26": .init(latitude: 1.28411, longitude: 103.85153), // Raffles Place
        "NS27": .init(latitude: 1.27637, longitude: 103.85497), // Marina Bay
        "NS28": .init(latitude: 1.27121, longitude: 103.86332), // Marina South Pier

        // North-East Line (NEL)
        "NE1":  .init(latitude: 1.26527, longitude: 103.82210), // HarbourFront
        "NE3":  .init(latitude: 1.28041, longitude: 103.83926), // Outram Park
        "NE4":  .init(latitude: 1.28477, longitude: 103.84410), // Chinatown
        "NE5":  .init(latitude: 1.28867, longitude: 103.84671), // Clarke Quay
        "NE6":  .init(latitude: 1.29853, longitude: 103.84563), // Dhoby Ghaut
        "NE7":  .init(latitude: 1.30680, longitude: 103.84937), // Little India
        "NE8":  .init(latitude: 1.31240, longitude: 103.85405), // Farrer Park
        "NE9":  .init(latitude: 1.31754, longitude: 103.86195), // Boon Keng
        "NE10": .init(latitude: 1.33105, longitude: 103.86922), // Potong Pasir
        "NE11": .init(latitude: 1.33889, longitude: 103.87080), // Woodleigh
        "NE12": .init(latitude: 1.34988, longitude: 103.87341), // Serangoon
        "NE13": .init(latitude: 1.36018, longitude: 103.88516), // Kovan
        "NE14": .init(latitude: 1.37140, longitude: 103.89236), // Hougang
        "NE15": .init(latitude: 1.38298, longitude: 103.89328), // Buangkok
        "NE16": .init(latitude: 1.39169, longitude: 103.89525), // Sengkang
        "NE17": .init(latitude: 1.40526, longitude: 103.90227), // Punggol

        // Circle Line (CCL)
        "CC1":  .init(latitude: 1.29853, longitude: 103.84563), // Dhoby Ghaut
        "CC2":  .init(latitude: 1.29680, longitude: 103.85093), // Bras Basah
        "CC3":  .init(latitude: 1.29306, longitude: 103.85534), // Esplanade
        "CC4":  .init(latitude: 1.29328, longitude: 103.86138), // Promenade
        "CC5":  .init(latitude: 1.29976, longitude: 103.86359), // Nicoll Highway
        "CC6":  .init(latitude: 1.30315, longitude: 103.87492), // Stadium
        "CC7":  .init(latitude: 1.30609, longitude: 103.88241), // Mountbatten
        "CC8":  .init(latitude: 1.30828, longitude: 103.88825), // Dakota
        "CC9":  .init(latitude: 1.31813, longitude: 103.89263), // Paya Lebar
        "CC10": .init(latitude: 1.32641, longitude: 103.89010), // MacPherson
        "CC11": .init(latitude: 1.33561, longitude: 103.88808), // Tai Seng
        "CC12": .init(latitude: 1.34270, longitude: 103.87979), // Bartley
        "CC13": .init(latitude: 1.34988, longitude: 103.87341), // Serangoon
        "CC14": .init(latitude: 1.35134, longitude: 103.86420), // Lorong Chuan
        "CC15": .init(latitude: 1.35099, longitude: 103.84812), // Bishan
        "CC16": .init(latitude: 1.34900, longitude: 103.83969), // Marymount
        "CC17": .init(latitude: 1.33765, longitude: 103.83962), // Caldecott
        "CC19": .init(latitude: 1.32237, longitude: 103.81550), // Botanic Gardens
        "CC20": .init(latitude: 1.31707, longitude: 103.80714), // Farrer Road
        "CC21": .init(latitude: 1.31123, longitude: 103.79620), // Holland Village
        "CC22": .init(latitude: 1.30715, longitude: 103.79014), // Buona Vista
        "CC23": .init(latitude: 1.29953, longitude: 103.78745), // one-north
        "CC24": .init(latitude: 1.29346, longitude: 103.78437), // Kent Ridge
        "CC25": .init(latitude: 1.28235, longitude: 103.78296), // Haw Par Villa
        "CC26": .init(latitude: 1.27620, longitude: 103.79122), // Pasir Panjang
        "CC27": .init(latitude: 1.27240, longitude: 103.80273), // Labrador Park
        "CC28": .init(latitude: 1.27090, longitude: 103.80983), // Telok Blangah
        "CC29": .init(latitude: 1.26527, longitude: 103.82210), // HarbourFront

        // Circle Line Extension (CE — Bayfront / Marina Bay)
        "CE1":  .init(latitude: 1.28194, longitude: 103.85937), // Bayfront
        "CE2":  .init(latitude: 1.27637, longitude: 103.85497), // Marina Bay

        // Downtown Line (DTL)
        "DT1":  .init(latitude: 1.38426, longitude: 103.74735), // Bukit Panjang
        "DT2":  .init(latitude: 1.38028, longitude: 103.76250), // Cashew
        "DT3":  .init(latitude: 1.37670, longitude: 103.77443), // Hillview
        "DT5":  .init(latitude: 1.34226, longitude: 103.77597), // Beauty World
        "DT6":  .init(latitude: 1.33063, longitude: 103.78026), // King Albert Park
        "DT7":  .init(latitude: 1.32985, longitude: 103.78771), // Sixth Avenue
        "DT8":  .init(latitude: 1.31984, longitude: 103.79395), // Tan Kah Kee
        "DT9":  .init(latitude: 1.32237, longitude: 103.81550), // Botanic Gardens
        "DT10": .init(latitude: 1.32268, longitude: 103.81792), // Stevens
        "DT11": .init(latitude: 1.31338, longitude: 103.83815), // Newton
        "DT12": .init(latitude: 1.30716, longitude: 103.83538), // Little India
        "DT13": .init(latitude: 1.30454, longitude: 103.85307), // Rochor
        "DT14": .init(latitude: 1.30068, longitude: 103.85604), // Bugis
        "DT15": .init(latitude: 1.29539, longitude: 103.85906), // Promenade
        "DT16": .init(latitude: 1.27954, longitude: 103.85273), // Downtown
        "DT17": .init(latitude: 1.28067, longitude: 103.85871), // Telok Ayer
        "DT18": .init(latitude: 1.28477, longitude: 103.84410), // Chinatown
        "DT19": .init(latitude: 1.29348, longitude: 103.84106), // Fort Canning
        "DT20": .init(latitude: 1.29969, longitude: 103.85626), // Bencoolen
        "DT21": .init(latitude: 1.30454, longitude: 103.85307), // Jalan Besar
        "DT22": .init(latitude: 1.31204, longitude: 103.86266), // Bendemeer
        "DT23": .init(latitude: 1.31790, longitude: 103.87146), // Geylang Bahru
        "DT24": .init(latitude: 1.32074, longitude: 103.88291), // Mattar
        "DT25": .init(latitude: 1.33561, longitude: 103.88808), // Tai Seng (interchange CC11)
        "DT26": .init(latitude: 1.33580, longitude: 103.89630), // Ubi
        "DT27": .init(latitude: 1.33253, longitude: 103.90249), // Kaki Bukit
        "DT28": .init(latitude: 1.33500, longitude: 103.91257), // Bedok North
        "DT29": .init(latitude: 1.33706, longitude: 103.92303), // Bedok Reservoir
        "DT30": .init(latitude: 1.34123, longitude: 103.93188), // Tampines West
        "DT31": .init(latitude: 1.35345, longitude: 103.94534), // Tampines
        "DT32": .init(latitude: 1.35660, longitude: 103.95469), // Tampines East
        "DT33": .init(latitude: 1.34996, longitude: 103.96252), // Upper Changi
        "DT34": .init(latitude: 1.31611, longitude: 103.96266), // Expo (interchange CG1)
        "DT35": .init(latitude: 1.32600, longitude: 103.93750), // Xilin
        "DT36": .init(latitude: 1.33580, longitude: 103.94600), // Sungei Bedok

        // Thomson-East Coast Line (TEL)
        "TE1":  .init(latitude: 1.43840, longitude: 103.78870), // Woodlands North
        "TE2":  .init(latitude: 1.43702, longitude: 103.78649), // Woodlands
        "TE3":  .init(latitude: 1.43185, longitude: 103.79358), // Woodlands South
        "TE4":  .init(latitude: 1.40503, longitude: 103.79390), // Springleaf
        "TE5":  .init(latitude: 1.39496, longitude: 103.80378), // Lentor
        "TE6":  .init(latitude: 1.38139, longitude: 103.81938), // Mayflower
        "TE7":  .init(latitude: 1.36964, longitude: 103.83279), // Bright Hill
        "TE8":  .init(latitude: 1.36100, longitude: 103.83572), // Upper Thomson
        "TE9":  .init(latitude: 1.33765, longitude: 103.83962), // Caldecott
        "TE11": .init(latitude: 1.32237, longitude: 103.81550), // Stevens
        "TE12": .init(latitude: 1.31338, longitude: 103.83815), // Newton
        "TE13": .init(latitude: 1.30419, longitude: 103.83202), // Orchard
        "TE14": .init(latitude: 1.30106, longitude: 103.83778), // Orchard Boulevard
        "TE15": .init(latitude: 1.29682, longitude: 103.84210), // Napier
        "TE16": .init(latitude: 1.29110, longitude: 103.84490), // Orchard Boulevard
        "TE17": .init(latitude: 1.28975, longitude: 103.84988), // Great World
        "TE18": .init(latitude: 1.28838, longitude: 103.85290), // Havelock
        "TE19": .init(latitude: 1.28649, longitude: 103.85490), // Outram Park
        "TE20": .init(latitude: 1.27392, longitude: 103.85397), // Maxwell
        "TE21": .init(latitude: 1.27620, longitude: 103.85937), // Shenton Way
        "TE22": .init(latitude: 1.27637, longitude: 103.85497), // Marina Bay
        "TE23": .init(latitude: 1.27121, longitude: 103.86332), // Marina South
        "TE24": .init(latitude: 1.27812, longitude: 103.86598), // Gardens by the Bay
        "TE25": .init(latitude: 1.30315, longitude: 103.87492), // Founders' Memorial
        "TE26": .init(latitude: 1.30315, longitude: 103.88241), // Tanjong Rhu
        "TE27": .init(latitude: 1.30315, longitude: 103.89010), // Katong Park
        "TE28": .init(latitude: 1.30315, longitude: 103.89800), // Tanjong Katong
        "TE29": .init(latitude: 1.30315, longitude: 103.90600), // Marine Parade
        "TE30": .init(latitude: 1.30315, longitude: 103.91300), // Marine Terrace
        "TE31": .init(latitude: 1.30315, longitude: 103.92000), // Siglap
        "TE32": .init(latitude: 1.30315, longitude: 103.92800), // Bayshore
    ]

    private static let allStations: [MRTStation] = {
        // Interchange map: station code → other lines through this station
        let interchanges: [String: [MRTLine]] = [
            // EWL ↔ ...
            "EW4":  [.ce], // Tanah Merah ↔ Changi Extension
            "EW8":  [.cc], // Paya Lebar
            "EW13": [.ns], // City Hall
            "EW14": [.ns], // Raffles Place
            "EW16": [.ne, .te], // Outram Park
            "EW21": [.cc], // Buona Vista
            "EW24": [.ns], // Jurong East
            // CGL
            "CG1":  [.dt], // Expo
            // NSL
            "NS1":  [.ew], "NS22": [], "NS24": [.ne, .cc],
            "NS25": [.ew], "NS26": [.ew], "NS27": [.te],
            // NEL
            "NE1":  [.cc], "NE3": [.ew, .te], "NE6": [.ns, .cc], "NE7": [.dt],
            "NE12": [.cc], "NE13": [], "NE16": [],
            // CCL
            "CC1":  [.ns, .ne], "CC4": [.dt], "CC9": [.ew], "CC11": [.dt],
            "CC13": [.ne], "CC15": [.ns], "CC17": [.te], "CC19": [.dt],
            "CC22": [.ew], "CC29": [.ne],
            "CE1":  [.dt], "CE2": [.ns, .te],
            // DTL
            "DT1":  [], "DT9": [.cc, .te], "DT10": [.te], "DT11": [.ns, .te],
            "DT12": [.ne], "DT14": [.ew], "DT15": [.cc], "DT16": [.te],
            "DT18": [.ne], "DT25": [.cc], "DT34": [.ce],
            // TEL
            "TE2":  [.ns], "TE9": [.cc], "TE11": [.dt], "TE12": [.ns, .dt],
            "TE13": [.ns], "TE19": [.ew, .ne], "TE22": [.ns],
        ]

        let raw: [(String, String, MRTLine)] = [
            // EWL
            ("EW1", "Pasir Ris", .ew), ("EW2", "Tampines", .ew), ("EW3", "Simei", .ew),
            ("EW4", "Tanah Merah", .ew), ("EW5", "Bedok", .ew), ("EW6", "Kembangan", .ew),
            ("EW7", "Eunos", .ew), ("EW8", "Paya Lebar", .ew), ("EW9", "Aljunied", .ew),
            ("EW10", "Kallang", .ew), ("EW11", "Lavender", .ew), ("EW12", "Bugis", .ew),
            ("EW13", "City Hall", .ew), ("EW14", "Raffles Place", .ew), ("EW15", "Tanjong Pagar", .ew),
            ("EW16", "Outram Park", .ew), ("EW17", "Tiong Bahru", .ew), ("EW18", "Redhill", .ew),
            ("EW19", "Queenstown", .ew), ("EW20", "Commonwealth", .ew), ("EW21", "Buona Vista", .ew),
            ("EW22", "Dover", .ew), ("EW23", "Clementi", .ew), ("EW24", "Jurong East", .ew),
            ("EW25", "Chinese Garden", .ew), ("EW26", "Lakeside", .ew), ("EW27", "Boon Lay", .ew),
            ("EW28", "Pioneer", .ew), ("EW29", "Joo Koon", .ew), ("EW30", "Gul Circle", .ew),
            ("EW31", "Tuas Crescent", .ew), ("EW32", "Tuas West Road", .ew), ("EW33", "Tuas Link", .ew),
            // CGL (Changi Extension)
            ("CG1", "Expo", .ce), ("CG2", "Changi Airport", .ce),
            // NSL
            ("NS1", "Jurong East", .ns), ("NS2", "Bukit Batok", .ns), ("NS3", "Bukit Gombak", .ns),
            ("NS4", "Choa Chu Kang", .ns), ("NS5", "Yew Tee", .ns), ("NS7", "Kranji", .ns),
            ("NS8", "Marsiling", .ns), ("NS9", "Woodlands", .ns), ("NS10", "Admiralty", .ns),
            ("NS11", "Sembawang", .ns), ("NS13", "Yishun", .ns), ("NS14", "Khatib", .ns),
            ("NS15", "Yio Chu Kang", .ns), ("NS16", "Ang Mo Kio", .ns), ("NS17", "Bishan", .ns),
            ("NS18", "Braddell", .ns), ("NS19", "Toa Payoh", .ns), ("NS20", "Novena", .ns),
            ("NS21", "Newton", .ns), ("NS22", "Orchard", .ns), ("NS23", "Somerset", .ns),
            ("NS24", "Dhoby Ghaut", .ns), ("NS25", "City Hall", .ns), ("NS26", "Raffles Place", .ns),
            ("NS27", "Marina Bay", .ns), ("NS28", "Marina South Pier", .ns),
            // NEL
            ("NE1", "HarbourFront", .ne), ("NE3", "Outram Park", .ne), ("NE4", "Chinatown", .ne),
            ("NE5", "Clarke Quay", .ne), ("NE6", "Dhoby Ghaut", .ne), ("NE7", "Little India", .ne),
            ("NE8", "Farrer Park", .ne), ("NE9", "Boon Keng", .ne), ("NE10", "Potong Pasir", .ne),
            ("NE11", "Woodleigh", .ne), ("NE12", "Serangoon", .ne), ("NE13", "Kovan", .ne),
            ("NE14", "Hougang", .ne), ("NE15", "Buangkok", .ne), ("NE16", "Sengkang", .ne),
            ("NE17", "Punggol", .ne),
            // CCL
            ("CC1", "Dhoby Ghaut", .cc), ("CC2", "Bras Basah", .cc), ("CC3", "Esplanade", .cc),
            ("CC4", "Promenade", .cc), ("CC5", "Nicoll Highway", .cc), ("CC6", "Stadium", .cc),
            ("CC7", "Mountbatten", .cc), ("CC8", "Dakota", .cc), ("CC9", "Paya Lebar", .cc),
            ("CC10", "MacPherson", .cc), ("CC11", "Tai Seng", .cc), ("CC12", "Bartley", .cc),
            ("CC13", "Serangoon", .cc), ("CC14", "Lorong Chuan", .cc), ("CC15", "Bishan", .cc),
            ("CC16", "Marymount", .cc), ("CC17", "Caldecott", .cc), ("CC19", "Botanic Gardens", .cc),
            ("CC20", "Farrer Road", .cc), ("CC21", "Holland Village", .cc), ("CC22", "Buona Vista", .cc),
            ("CC23", "one-north", .cc), ("CC24", "Kent Ridge", .cc), ("CC25", "Haw Par Villa", .cc),
            ("CC26", "Pasir Panjang", .cc), ("CC27", "Labrador Park", .cc), ("CC28", "Telok Blangah", .cc),
            ("CC29", "HarbourFront", .cc), ("CE1", "Bayfront", .cc), ("CE2", "Marina Bay", .cc),
            // DTL
            ("DT1", "Bukit Panjang", .dt), ("DT2", "Cashew", .dt), ("DT3", "Hillview", .dt),
            ("DT5", "Beauty World", .dt), ("DT6", "King Albert Park", .dt), ("DT7", "Sixth Avenue", .dt),
            ("DT8", "Tan Kah Kee", .dt), ("DT9", "Botanic Gardens", .dt), ("DT10", "Stevens", .dt),
            ("DT11", "Newton", .dt), ("DT12", "Little India", .dt), ("DT13", "Rochor", .dt),
            ("DT14", "Bugis", .dt), ("DT15", "Promenade", .dt), ("DT16", "Downtown", .dt),
            ("DT17", "Telok Ayer", .dt), ("DT18", "Chinatown", .dt), ("DT19", "Fort Canning", .dt),
            ("DT20", "Bencoolen", .dt), ("DT21", "Jalan Besar", .dt), ("DT22", "Bendemeer", .dt),
            ("DT23", "Geylang Bahru", .dt), ("DT24", "Mattar", .dt), ("DT25", "Tai Seng", .dt),
            ("DT26", "Ubi", .dt), ("DT27", "Kaki Bukit", .dt), ("DT28", "Bedok North", .dt),
            ("DT29", "Bedok Reservoir", .dt), ("DT30", "Tampines West", .dt), ("DT31", "Tampines", .dt),
            ("DT32", "Tampines East", .dt), ("DT33", "Upper Changi", .dt), ("DT34", "Expo", .dt),
            ("DT35", "Xilin", .dt), ("DT36", "Sungei Bedok", .dt),
            // TEL
            ("TE1", "Woodlands North", .te), ("TE2", "Woodlands", .te), ("TE3", "Woodlands South", .te),
            ("TE4", "Springleaf", .te), ("TE5", "Lentor", .te), ("TE6", "Mayflower", .te),
            ("TE7", "Bright Hill", .te), ("TE8", "Upper Thomson", .te), ("TE9", "Caldecott", .te),
            ("TE11", "Stevens", .te), ("TE12", "Newton", .te), ("TE13", "Orchard", .te),
            ("TE14", "Great World", .te), ("TE15", "Havelock", .te), ("TE16", "Outram Park", .te),
            ("TE17", "Maxwell", .te), ("TE18", "Shenton Way", .te), ("TE19", "Marina Bay", .te),
            ("TE20", "Marina South", .te), ("TE22", "Gardens by the Bay", .te),
            ("TE23", "Tanjong Rhu", .te), ("TE24", "Katong Park", .te),
            ("TE25", "Tanjong Katong", .te), ("TE26", "Marine Parade", .te),
            ("TE27", "Marine Terrace", .te), ("TE28", "Siglap", .te), ("TE29", "Bayshore", .te),
        ]

        return raw.map { code, name, line in
            MRTStation(
                id: code,
                name: name,
                line: line,
                interchangeLines: interchanges[code] ?? [],
                distanceMeters: nil
            )
        }
    }()
}
