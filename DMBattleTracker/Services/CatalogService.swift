import Foundation
import SwiftUI

struct FlexBool: Decodable {
    let boolValue: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let b = try? container.decode(Bool.self) {
            boolValue = b
        } else if let i = try? container.decode(Int.self) {
            boolValue = i != 0
        } else if let s = try? container.decode(String.self) {
            let lower = s.lowercased()
            boolValue = lower == "yes" || lower == "true" || lower == "1"
        } else {
            boolValue = false
        }
    }
}

@MainActor final class CatalogService: ObservableObject {
    static let shared = CatalogService()

    @Published private(set) var allItems: [CatalogItem] = []
    @Published private(set) var isLoaded: Bool = false

    private init() {}

    func load() async {
        guard !isLoaded else { return }
        var merged: [String: CatalogItem] = [:]
        for item in loadArmor() { merged[item.slug] = item }
        for item in loadWeapons() { merged[item.slug] = item }
        for item in loadSpells() { merged[item.slug] = item }
        for item in loadMagicItems() { merged[item.slug] = item }
        let hidden = loadHiddenSlugs()
        allItems = merged.values.filter { !hidden.contains($0.slug) }.sorted { $0.name < $1.name }
        isLoaded = true
    }

    func items(type: CatalogItemType? = nil, search: String = "", rarity: CatalogItemRarity? = nil) -> [CatalogItem] {
        allItems.filter { item in
            let matchesType = type == nil || item.type == type
            let matchesSearch = search.isEmpty || item.name.localizedCaseInsensitiveContains(search)
            let matchesRarity = rarity == nil || item.rarity == rarity
            return matchesType && matchesSearch && matchesRarity
        }
    }

    func hideItem(slug: String) {
        var hidden = loadHiddenSlugs()
        hidden.insert(slug)
        saveHiddenSlugs(hidden)
        allItems.removeAll { $0.slug == slug }
    }

    private func loadHiddenSlugs() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: "hiddenCatalogSlugs"),
              let set = try? JSONDecoder().decode(Set<String>.self, from: data)
        else { return [] }
        return set
    }

    private func saveHiddenSlugs(_ set: Set<String>) {
        if let data = try? JSONEncoder().encode(set) {
            UserDefaults.standard.set(data, forKey: "hiddenCatalogSlugs")
        }
    }

    func item(slug: String) -> CatalogItem? {
        allItems.first { $0.slug == slug }
    }

    private struct ArmorRaw: Decodable {
        var name: String
        var category: String?
        var cost: String?
        var weight: String?
        var ac_string: String?
        var desc: String?
        var source: String?
    }

    private struct WeaponRaw: Decodable {
        var name: String
        var category: String?
        var cost: String?
        var weight: String?
        var damage_dice: String?
        var desc: String?
        var source: String?
    }

    private struct MagicItemRaw: Decodable {
        var name: String
        var category: String?
        var rarity: String?
        var cost: String?
        var weight: String?
        var desc: String?
        var attunement: FlexBool?
        var source: String?
    }

    private struct SpellRaw: Decodable {
        var name: String
        var level: String?
        var school: String?
        var casting_time: String?
        var range: String?
        var components: String?
        var duration: String?
        var desc: String?
        var concentration: FlexBool?
        var ritual: FlexBool?
        var source: String?
        var material: String?
        var higher_level: String?
        var dnd_class: String?
    }

    private func loadArmor() -> [CatalogItem] {
        guard let url = Bundle.main.url(forResource: "armor-export", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raws = try? JSONDecoder().decode([ArmorRaw].self, from: data)
        else { return [] }
        return raws.map { raw in
            CatalogItem(
                slug: CatalogItem.slug(from: raw.name),
                name: raw.name,
                type: .armor,
                category: raw.category ?? "Armor",
                cost: raw.cost ?? "—",
                desc: raw.desc ?? "",
                source: raw.source ?? "",
                weight: raw.weight,
                rarity: .unknown,
                attunement: false,
                acString: raw.ac_string,
                damageDice: nil,
                level: nil, school: nil, castingTime: nil, spellRange: nil,
                components: nil, duration: nil,
                concentration: false, ritual: false,
                dndClass: nil, material: nil, higherLevel: nil
            )
        }
    }

    private func loadWeapons() -> [CatalogItem] {
        guard let url = Bundle.main.url(forResource: "weapons-export", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raws = try? JSONDecoder().decode([WeaponRaw].self, from: data)
        else { return [] }
        return raws.map { raw in
            CatalogItem(
                slug: CatalogItem.slug(from: raw.name),
                name: raw.name,
                type: .weapon,
                category: raw.category ?? "Weapon",
                cost: raw.cost ?? "—",
                desc: raw.desc ?? "",
                source: raw.source ?? "",
                weight: raw.weight,
                rarity: .unknown,
                attunement: false,
                acString: nil,
                damageDice: raw.damage_dice,
                level: nil, school: nil, castingTime: nil, spellRange: nil,
                components: nil, duration: nil,
                concentration: false, ritual: false,
                dndClass: nil, material: nil, higherLevel: nil
            )
        }
    }

    private func loadMagicItems() -> [CatalogItem] {
        guard let url = Bundle.main.url(forResource: "magicitems-export", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raws = try? JSONDecoder().decode([MagicItemRaw].self, from: data)
        else { return [] }
        return raws.map { raw in
            CatalogItem(
                slug: CatalogItem.slug(from: raw.name),
                name: raw.name,
                type: .magicItem,
                category: raw.category ?? "Magic Item",
                cost: raw.cost ?? "—",
                desc: raw.desc ?? "",
                source: raw.source ?? "",
                weight: raw.weight,
                rarity: CatalogItemRarity.from(raw.rarity),
                attunement: raw.attunement?.boolValue ?? false,
                acString: nil,
                damageDice: nil,
                level: nil, school: nil, castingTime: nil, spellRange: nil,
                components: nil, duration: nil,
                concentration: false, ritual: false,
                dndClass: nil, material: nil, higherLevel: nil
            )
        }
    }

    private func loadSpells() -> [CatalogItem] {
        guard let url = Bundle.main.url(forResource: "spells-export", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raws = try? JSONDecoder().decode([SpellRaw].self, from: data)
        else { return [] }
        return raws.map { raw in
            CatalogItem(
                slug: CatalogItem.slug(from: raw.name),
                name: raw.name,
                type: .spell,
                category: raw.school.map { "\($0) Spell" } ?? "Spell",
                cost: "—",
                desc: raw.desc ?? "",
                source: raw.source ?? "",
                weight: nil,
                rarity: .unknown,
                attunement: false,
                acString: nil,
                damageDice: nil,
                level: raw.level,
                school: raw.school,
                castingTime: raw.casting_time,
                spellRange: raw.range,
                components: raw.components,
                duration: raw.duration,
                concentration: raw.concentration?.boolValue ?? false,
                ritual: raw.ritual?.boolValue ?? false,
                dndClass: raw.dnd_class,
                material: raw.material,
                higherLevel: raw.higher_level
            )
        }
    }
}
