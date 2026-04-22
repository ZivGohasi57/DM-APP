import Foundation
import SwiftUI
import SwiftData

enum ShopType: String, Codable, CaseIterable {
    case weapons = "Weapons & Armor"
    case apothecary = "Apothecary"
    case library = "Library"

    var icon: String {
        switch self {
        case .weapons: return "shield.lefthalf.filled.slash"
        case .apothecary: return "cross.vial.fill"
        case .library: return "books.vertical.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .weapons: return Color(red: 0.85, green: 0.35, blue: 0.2)
        case .apothecary: return Color(red: 0.2, green: 0.7, blue: 0.4)
        case .library: return Color(red: 0.2, green: 0.65, blue: 0.7)
        }
    }

    var defaultCatalogTypes: [CatalogItemType] {
        switch self {
        case .weapons: return [.weapon, .armor]
        case .apothecary: return [.magicItem]
        case .library: return [.spell]
        }
    }
}

enum ShopQuality: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var rarityWeights: [(CatalogItemRarity, Int)] {
        switch self {
        case .low:    return [(.common, 50), (.uncommon, 35), (.rare, 10), (.veryRare, 4), (.legendary, 1)]
        case .medium: return [(.common, 25), (.uncommon, 40), (.rare, 25), (.veryRare, 9), (.legendary, 1)]
        case .high:   return [(.common, 10), (.uncommon, 25), (.rare, 40), (.veryRare, 22), (.legendary, 3)]
        }
    }
}

enum ShopQuestType: String, Codable, CaseIterable {
    case none = "None"
    case main = "Main Quest"
    case side = "Side Quest"

    var badge: String? {
        switch self {
        case .none: return nil
        case .main: return "Main"
        case .side: return "Side"
        }
    }

    var color: Color {
        switch self {
        case .none: return .clear
        case .main: return .orange
        case .side: return .indigo
        }
    }
}

struct ShopInventoryEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var slug: String
    var name: String
    var itemTypeRaw: String
    var category: String
    var catalogCost: String
    var customPrice: Double?
    var quantity: Int = 1
    var notes: String = ""
    var inStock: Bool = true

    var itemType: CatalogItemType { CatalogItemType(rawValue: itemTypeRaw) ?? .magicItem }

    var displayPrice: String {
        if let p = customPrice { return "\(Int(p)) gp" }
        return catalogCost.isEmpty ? "—" : catalogCost
    }

    init(from item: CatalogItem, quantity: Int = 1) {
        self.slug = item.slug
        self.name = item.name
        self.itemTypeRaw = item.type.rawValue
        self.category = item.category
        self.catalogCost = item.cost
        self.quantity = quantity
    }
}

@Model final class Shop {
    var id: UUID = UUID()
    var campaignID: UUID
    var cityID: UUID
    var name: String
    var shopTypeRaw: String
    var qualityRaw: String = ShopQuality.medium.rawValue
    var questTypeRaw: String
    var shopDescription: String
    var ownerName: String
    var ownerNotes: String
    var startingGold: Double
    var totalEarned: Double
    var storyID: UUID?
    var ownerNPCID: UUID?
    var sortOrder: Int
    var linkedStoryName: String
    private var inventoryJSON: Data

    init(name: String, campaignID: UUID, cityID: UUID, shopType: ShopType = .weapons, quality: ShopQuality = .medium) {
        self.id = UUID()
        self.campaignID = campaignID
        self.cityID = cityID
        self.name = name
        self.shopTypeRaw = shopType.rawValue
        self.qualityRaw = quality.rawValue
        self.questTypeRaw = ShopQuestType.none.rawValue
        self.shopDescription = ""
        self.ownerName = ""
        self.ownerNotes = ""
        self.startingGold = 0
        self.totalEarned = 0
        self.sortOrder = 0
        self.linkedStoryName = ""
        self.inventoryJSON = (try? JSONEncoder().encode([ShopInventoryEntry]())) ?? Data()
    }

    var shopType: ShopType {
        get { ShopType(rawValue: shopTypeRaw) ?? .weapons }
        set { shopTypeRaw = newValue.rawValue }
    }

    var quality: ShopQuality {
        get { ShopQuality(rawValue: qualityRaw) ?? .medium }
        set { qualityRaw = newValue.rawValue }
    }

    var questType: ShopQuestType {
        get { ShopQuestType(rawValue: questTypeRaw) ?? .none }
        set { questTypeRaw = newValue.rawValue }
    }

    var inventory: [ShopInventoryEntry] {
        (try? JSONDecoder().decode([ShopInventoryEntry].self, from: inventoryJSON)) ?? []
    }

    func setInventory(_ entries: [ShopInventoryEntry]) {
        inventoryJSON = (try? JSONEncoder().encode(entries)) ?? Data()
    }

    var currentBalance: Double { startingGold + totalEarned }
}

struct ShopPricingEngine {
    static func price(for item: CatalogItem) -> Double {
        let isConsumable = item.category == "Potion" || item.category == "Scroll"
        let base: Double
        switch item.rarity {
        case .common:
            base = Double((Int.random(in: 1...6) + 1) * 10)
        case .uncommon:
            base = Double(Int.random(in: 1...6) * 100)
        case .rare:
            base = Double((Int.random(in: 1...10) + Int.random(in: 1...10)) * 1000)
        case .veryRare:
            base = Double((Int.random(in: 1...4) + 1) * 10_000)
        case .legendary:
            base = Double((Int.random(in: 1...6) + Int.random(in: 1...6)) * 25_000)
        default:
            let raw = item.cost.components(separatedBy: " ").first ?? ""
            return Double(raw.replacingOccurrences(of: ",", with: "")) ?? 0
        }
        return isConsumable ? base / 2.0 : base
    }
}

@MainActor struct ShopRandomizer {
    static func randomize(shop: Shop, catalog: CatalogService) {
        let pool = buildPool(for: shop.shopType, catalog: catalog)
        var result: [ShopInventoryEntry] = []
        var usedSlugs = Set<String>()
        var attempts = 0

        while result.count < 10 && attempts < 150 {
            attempts += 1
            let rarity = weightedRarity(quality: shop.quality)
            let candidatePool = pool.filter {
                !usedSlugs.contains($0.slug) &&
                (rarity == .common
                    ? ($0.rarity == .common || $0.rarity == .unknown)
                    : $0.rarity == rarity)
            }
            guard let item = candidatePool.randomElement() else { continue }
            var entry = ShopInventoryEntry(from: item)
            let price = ShopPricingEngine.price(for: item)
            if price > 0 { entry.customPrice = price }
            result.append(entry)
            usedSlugs.insert(item.slug)
        }

        shop.setInventory(result)
    }

    private static func buildPool(for type: ShopType, catalog: CatalogService) -> [CatalogItem] {
        switch type {
        case .apothecary:
            let names = [
                "Potion of Healing", "Potion of Greater Healing",
                "Potion of Superior Healing", "Potion of Supreme Healing"
            ]
            return names.compactMap { catalog.item(slug: CatalogItem.slug(from: $0)) }
        case .library:
            return catalog.items(type: .magicItem).filter {
                $0.category == "Scroll" && $0.rarity != .artifact
            }
        case .weapons:
            let mundane = catalog.items(type: .weapon) + catalog.items(type: .armor)
            let magic = catalog.items(type: .magicItem).filter {
                ($0.category == "Weapon" || $0.category == "Armor") && $0.rarity != .artifact
            }
            return mundane + magic
        }
    }

    private static func weightedRarity(quality: ShopQuality) -> CatalogItemRarity {
        let weights = quality.rarityWeights
        let total = weights.reduce(0) { $0 + $1.1 }
        var roll = Int.random(in: 0..<total)
        for (rarity, weight) in weights {
            if roll < weight { return rarity }
            roll -= weight
        }
        return .common
    }
}
