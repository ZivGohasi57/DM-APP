import Foundation

enum DamageType: String, CaseIterable, Codable, Identifiable, Hashable {
    case slashing = "Slashing"
    case piercing = "Piercing"
    case bludgeoning = "Bludgeoning"
    case fire = "Fire"
    case cold = "Cold"
    case poison = "Poison"
    case acid = "Acid"
    case psychic = "Psychic"
    case necrotic = "Necrotic"
    case radiant = "Radiant"
    case lightning = "Lightning"
    case thunder = "Thunder"
    case force = "Force"

    var id: String { rawValue }
}

enum DamageResponse: String, CaseIterable, Codable, Identifiable, Hashable {
    case regular = "Regular"
    case resistant = "Resistant"
    case immune = "Immune"
    case vulnerable = "Vulnerable"

    var id: String { rawValue }

    var abbreviation: String {
        switch self {
        case .regular: return "—"
        case .resistant: return "½"
        case .immune: return "0"
        case .vulnerable: return "2×"
        }
    }

    var shortCode: String {
        switch self {
        case .regular: return "x"
        case .resistant: return "r"
        case .immune: return "i"
        case .vulnerable: return "v"
        }
    }
}
