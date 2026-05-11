import Foundation

struct TransitAlert: Identifiable, Hashable {
    enum Severity: String, Hashable { case danger, warning, info, success }
    enum Kind: String, Hashable { case mrt, bus, forYou, general }

    let id: UUID
    let severity: Severity
    let kind: Kind
    let tag: String
    let title: String
    let body: String?
    let timeLabel: String

    init(
        id: UUID = UUID(),
        severity: Severity,
        kind: Kind,
        tag: String,
        title: String,
        body: String? = nil,
        timeLabel: String
    ) {
        self.id = id
        self.severity = severity
        self.kind = kind
        self.tag = tag
        self.title = title
        self.body = body
        self.timeLabel = timeLabel
    }
}
