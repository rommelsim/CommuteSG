import Foundation

// LTA DataMall — BusArrivalv2
// https://datamall.lta.gov.sg/content/datamall/en/dynamic-data.html

struct LTABusArrivalResponse: Decodable {
    let busStopCode: String
    let services: [LTABusService]

    enum CodingKeys: String, CodingKey {
        case busStopCode = "BusStopCode"
        case services    = "Services"
    }
}

struct LTABusService: Decodable {
    let serviceNo: String
    let `operator`: String
    let nextBus: LTANextBus
    let nextBus2: LTANextBus
    let nextBus3: LTANextBus

    enum CodingKeys: String, CodingKey {
        case serviceNo = "ServiceNo"
        case `operator` = "Operator"
        case nextBus   = "NextBus"
        case nextBus2  = "NextBus2"
        case nextBus3  = "NextBus3"
    }
}

struct LTANextBus: Decodable {
    let originCode: String
    let destinationCode: String
    let estimatedArrival: String   // ISO8601 with offset, may be empty
    let monitored: Int?            // 1 = live estimate, 0 = scheduled
    let latitude: String?
    let longitude: String?
    let load: String               // SEA / SDA / LSD / ""
    let feature: String            // WAB or ""
    let type: String               // SD / DD / BD / ""

    enum CodingKeys: String, CodingKey {
        case originCode       = "OriginCode"
        case destinationCode  = "DestinationCode"
        case estimatedArrival = "EstimatedArrival"
        case monitored        = "Monitored"
        case latitude         = "Latitude"
        case longitude        = "Longitude"
        case load             = "Load"
        case feature          = "Feature"
        case type             = "Type"
    }

    var coordinateDouble: (lat: Double, lon: Double)? {
        guard let lat = latitude.flatMap(Double.init), let lon = longitude.flatMap(Double.init),
              !(lat == 0 && lon == 0) else { return nil }
        return (lat, lon)
    }
}

// LTA DataMall — BusRoutes

struct LTABusRoutesResponse: Decodable {
    let value: [LTABusRoute]
    enum CodingKeys: String, CodingKey { case value = "value" }
}

struct LTABusRoute: Decodable {
    let serviceNo: String
    let `operator`: String
    let direction: Int
    let stopSequence: Int
    let busStopCode: String
    let distance: Double?

    enum CodingKeys: String, CodingKey {
        case serviceNo    = "ServiceNo"
        case `operator`   = "Operator"
        case direction    = "Direction"
        case stopSequence = "StopSequence"
        case busStopCode  = "BusStopCode"
        case distance     = "Distance"
    }
}

// LTA DataMall — BusStops

struct LTABusStopsResponse: Decodable {
    let value: [LTABusStop]
    enum CodingKeys: String, CodingKey { case value = "value" }
}

struct LTABusStop: Decodable {
    let busStopCode: String
    let roadName: String
    let description: String
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case busStopCode = "BusStopCode"
        case roadName    = "RoadName"
        case description = "Description"
        case latitude    = "Latitude"
        case longitude   = "Longitude"
    }
}

// LTA DataMall — Station Crowd Density Real-time

struct LTAStationCrowdResponse: Decodable {
    let value: [LTAStationCrowd]
    enum CodingKeys: String, CodingKey { case value = "value" }
}

struct LTAStationCrowd: Decodable {
    let station: String
    let startTime: String
    let endTime: String
    let crowdLevel: String   // "l" / "m" / "h" / "NA"

    enum CodingKeys: String, CodingKey {
        case station    = "Station"
        case startTime  = "StartTime"
        case endTime    = "EndTime"
        case crowdLevel = "CrowdLevel"
    }
}

// LTA DataMall — Station Crowd Density Forecast (next ~1-2h, 30-min slots)

struct LTAStationCrowdForecastResponse: Decodable {
    let value: [LTAStationCrowdForecastEnvelope]
    enum CodingKeys: String, CodingKey { case value = "value" }
}

struct LTAStationCrowdForecastEnvelope: Decodable {
    let stations: [LTAStationCrowdForecast]
    enum CodingKeys: String, CodingKey { case stations = "Stations" }
}

struct LTAStationCrowdForecast: Decodable {
    let station: String
    let interval: [LTAStationCrowdForecastInterval]

    enum CodingKeys: String, CodingKey {
        case station  = "Station"
        case interval = "Interval"
    }
}

struct LTAStationCrowdForecastInterval: Decodable {
    let start: String         // ISO-8601, slot start
    let crowdLevel: String    // "l" / "m" / "h" / "NA"

    enum CodingKeys: String, CodingKey {
        case start      = "Start"
        case crowdLevel = "CrowdLevel"
    }
}

// LTA DataMall — Facilities Maintenance v2 (lift maintenance)

struct LTAFacilitiesMaintenanceResponse: Decodable {
    let value: [LTAFacilityMaintenance]
    enum CodingKeys: String, CodingKey { case value = "value" }
}

struct LTAFacilityMaintenance: Decodable {
    let line: String
    let stationCode: String
    let stationName: String
    let liftId: String?
    let liftDesc: String

    enum CodingKeys: String, CodingKey {
        case line        = "Line"
        case stationCode = "StationCode"
        case stationName = "StationName"
        case liftId      = "LiftID"
        case liftDesc    = "LiftDesc"
    }
}

// LTA DataMall — TrainServiceAlerts

struct LTATrainAlertResponse: Decodable {
    let value: LTATrainAlertValue
    enum CodingKeys: String, CodingKey { case value = "value" }
}

struct LTATrainAlertValue: Decodable {
    let status: Int                         // 1 = normal, 2 = disrupted
    let affectedSegments: [LTAAffectedSegment]
    let message: [LTAAlertMessage]

    enum CodingKeys: String, CodingKey {
        case status            = "Status"
        case affectedSegments  = "AffectedSegments"
        case message           = "Message"
    }
}

struct LTAAffectedSegment: Decodable {
    let line: String
    let direction: String
    let stations: String
    let freePublicBus: String
    let freeMRTShuttle: String

    enum CodingKeys: String, CodingKey {
        case line            = "Line"
        case direction       = "Direction"
        case stations        = "Stations"
        case freePublicBus   = "FreePublicBus"
        case freeMRTShuttle  = "FreeMRTShuttle"
    }
}

struct LTAAlertMessage: Decodable {
    let content: String
    let createdDate: String

    enum CodingKeys: String, CodingKey {
        case content     = "Content"
        case createdDate = "CreatedDate"
    }
}
