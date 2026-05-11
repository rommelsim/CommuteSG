import Foundation

struct SavedPlace: Identifiable, Hashable, Codable {
    enum Kind: String, Codable, CaseIterable, Hashable {
        case home, work, custom

        var symbol: String {
            switch self {
            case .home: "house.fill"
            case .work: "briefcase.fill"
            case .custom: "mappin.circle.fill"
            }
        }
    }

    let id: UUID
    var kind: Kind
    var label: String
    var address: String

    init(id: UUID = UUID(), kind: Kind, label: String, address: String) {
        self.id = id
        self.kind = kind
        self.label = label
        self.address = address
    }
}
