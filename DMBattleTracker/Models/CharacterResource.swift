import Foundation

enum RestType: String, Codable, CaseIterable, Identifiable {
    case longRest = "Long Rest"
    case shortRest = "Short Rest"
    var id: String { rawValue }
}

struct CharacterResource: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var maxValue: Int
    var currentValue: Int
    var restType: RestType = .longRest
    var requiresConcentration: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name, maxValue, currentValue, restType, requiresConcentration
    }

    init(id: UUID = UUID(), name: String, maxValue: Int, currentValue: Int, restType: RestType = .longRest, requiresConcentration: Bool = false) {
        self.id = id
        self.name = name
        self.maxValue = maxValue
        self.currentValue = currentValue
        self.restType = restType
        self.requiresConcentration = requiresConcentration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        maxValue = try container.decode(Int.self, forKey: .maxValue)
        currentValue = try container.decode(Int.self, forKey: .currentValue)
        restType = try container.decodeIfPresent(RestType.self, forKey: .restType) ?? .longRest
        requiresConcentration = try container.decodeIfPresent(Bool.self, forKey: .requiresConcentration) ?? false
    }
}
