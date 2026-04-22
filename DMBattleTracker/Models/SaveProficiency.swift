import Foundation

enum SaveProficiency: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case proficient = "Proficient"
    case expertise = "Expertise"

    var id: String { rawValue }

    var multiplier: Int {
        switch self {
        case .none: return 0
        case .proficient: return 1
        case .expertise: return 2
        }
    }

    var abbreviation: String {
        switch self {
        case .none: return "—"
        case .proficient: return "Prof"
        case .expertise: return "Exp"
        }
    }
}

enum Ability: String, CaseIterable, Codable, Identifiable {
    case strength = "STR"
    case dexterity = "DEX"
    case constitution = "CON"
    case intelligence = "INT"
    case wisdom = "WIS"
    case charisma = "CHA"

    var id: String { rawValue }

    var fullName: String {
        switch self {
        case .strength: return "Strength"
        case .dexterity: return "Dexterity"
        case .constitution: return "Constitution"
        case .intelligence: return "Intelligence"
        case .wisdom: return "Wisdom"
        case .charisma: return "Charisma"
        }
    }
}
