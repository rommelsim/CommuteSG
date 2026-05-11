import Foundation

struct JourneyOption: Identifiable, Hashable {
    let id = UUID()
    let durationMinutes: Int
    let walkMinutes: Int
    let fareSGD: Double
    let segments: [Segment]
    let crowd: CrowdLevel
    let leavesInMinutes: Int
    let isBest: Bool

    enum Segment: Hashable {
        case walk(minutes: Int)
        case mrt(MRTLine, minutes: Int)
        case bus(serviceNo: String, minutes: Int)

        var minutes: Int {
            switch self {
            case .walk(let m): m
            case .mrt(_, let m): m
            case .bus(_, let m): m
            }
        }

        var isWalk: Bool {
            if case .walk = self { return true } else { return false }
        }
    }

    var transferCount: Int {
        max(0, segments.filter { !$0.isWalk }.count - 1)
    }

    func departure(from now: Date = Date()) -> Date {
        now.addingTimeInterval(TimeInterval(leavesInMinutes * 60))
    }

    func arrival(from now: Date = Date()) -> Date {
        departure(from: now).addingTimeInterval(TimeInterval(durationMinutes * 60))
    }
}
