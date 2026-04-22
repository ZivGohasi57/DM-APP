import SwiftUI

enum CatalogItemType: String, Codable, CaseIterable {
    case weapon = "Weapon"
    case armor = "Armor"
    case magicItem = "Magic Item"
    case spell = "Spell"

    var icon: String {
        switch self {
        case .weapon: return "shield.lefthalf.filled.slash"
        case .armor: return "shield.fill"
        case .magicItem: return "sparkles"
        case .spell: return "wand.and.stars"
        }
    }

    var accentColor: Color {
        switch self {
        case .weapon: return Color(red: 0.85, green: 0.35, blue: 0.2)
        case .armor: return Color(red: 0.3, green: 0.5, blue: 0.85)
        case .magicItem: return Color(red: 0.65, green: 0.3, blue: 0.9)
        case .spell: return Color(red: 0.2, green: 0.75, blue: 0.8)
        }
    }
}

enum CatalogItemRarity: String, Codable, CaseIterable {
    case common = "Common"
    case uncommon = "Uncommon"
    case rare = "Rare"
    case veryRare = "Very Rare"
    case legendary = "Legendary"
    case artifact = "Artifact"
    case varies = "Varies"
    case unknown = "Unknown"

    var color: Color {
        switch self {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .veryRare: return .purple
        case .legendary: return .orange
        case .artifact: return .red
        case .varies: return .teal
        case .unknown: return .secondary
        }
    }

    static func from(_ string: String?) -> CatalogItemRarity {
        guard let s = string?.lowercased().trimmingCharacters(in: .whitespaces) else { return .unknown }
        switch s {
        case "common": return .common
        case "uncommon": return .uncommon
        case "rare": return .rare
        case "very rare": return .veryRare
        case "legendary": return .legendary
        case "artifact": return .artifact
        case "varies": return .varies
        default: return .unknown
        }
    }
}

struct CatalogItem: Identifiable, Codable, Hashable {
    var id: String { slug }
    var slug: String
    var name: String
    var type: CatalogItemType
    var category: String
    var cost: String
    var desc: String
    var source: String
    var weight: String?
    var rarity: CatalogItemRarity
    var attunement: Bool
    var acString: String?
    var damageDice: String?
    var level: String?
    var school: String?
    var castingTime: String?
    var spellRange: String?
    var components: String?
    var duration: String?
    var concentration: Bool
    var ritual: Bool
    var dndClass: String?
    var material: String?
    var higherLevel: String?

    static func slug(from name: String) -> String {
        name.lowercased()
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : Character("-") }
            .reduce("") { acc, c in
                if c == "-" && acc.last == "-" { return acc }
                return acc + String(c)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

struct StoryItemEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var slug: String
    var name: String
    var itemTypeRaw: String
    var notes: String = ""
    var isReward: Bool = false

    var itemType: CatalogItemType { CatalogItemType(rawValue: itemTypeRaw) ?? .magicItem }
}
