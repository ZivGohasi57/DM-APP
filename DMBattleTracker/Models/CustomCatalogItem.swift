import Foundation
import SwiftData
import SwiftUI

@Model final class CustomCatalogItem {
    var id: UUID
    var campaignID: UUID
    var name: String
    var itemTypeRaw: String
    var category: String
    var cost: String
    var desc: String
    var weight: String
    var rarityRaw: String
    var attunement: Bool
    var acString: String
    var damageDice: String
    var spellLevel: String
    var school: String
    var castingTime: String
    var spellRange: String
    var components: String
    var duration: String
    var concentration: Bool
    var ritual: Bool

    init(campaignID: UUID, name: String, itemType: CatalogItemType) {
        self.id = UUID()
        self.campaignID = campaignID
        self.name = name
        self.itemTypeRaw = itemType.rawValue
        self.category = ""
        self.cost = ""
        self.desc = ""
        self.weight = ""
        self.rarityRaw = CatalogItemRarity.unknown.rawValue
        self.attunement = false
        self.acString = ""
        self.damageDice = ""
        self.spellLevel = ""
        self.school = ""
        self.castingTime = ""
        self.spellRange = ""
        self.components = ""
        self.duration = ""
        self.concentration = false
        self.ritual = false
    }

    var itemType: CatalogItemType {
        CatalogItemType(rawValue: itemTypeRaw) ?? .magicItem
    }

    var rarity: CatalogItemRarity {
        CatalogItemRarity(rawValue: rarityRaw) ?? .unknown
    }

    func toCatalogItem() -> CatalogItem {
        CatalogItem(
            slug: "custom-\(id.uuidString)",
            name: name,
            type: itemType,
            category: category.isEmpty ? itemType.rawValue : category,
            cost: cost.isEmpty ? "—" : cost,
            desc: desc,
            source: "Custom",
            weight: weight.isEmpty ? nil : weight,
            rarity: rarity,
            attunement: attunement,
            acString: acString.isEmpty ? nil : acString,
            damageDice: damageDice.isEmpty ? nil : damageDice,
            level: spellLevel.isEmpty ? nil : spellLevel,
            school: school.isEmpty ? nil : school,
            castingTime: castingTime.isEmpty ? nil : castingTime,
            spellRange: spellRange.isEmpty ? nil : spellRange,
            components: components.isEmpty ? nil : components,
            duration: duration.isEmpty ? nil : duration,
            concentration: concentration,
            ritual: ritual,
            dndClass: nil,
            material: nil,
            higherLevel: nil
        )
    }
}

extension CustomCatalogItem {
    static func fromSlug(_ slug: String, in items: [CustomCatalogItem]) -> CustomCatalogItem? {
        guard slug.hasPrefix("custom-"),
              let uuid = UUID(uuidString: String(slug.dropFirst(7)))
        else { return nil }
        return items.first { $0.id == uuid }
    }
}
