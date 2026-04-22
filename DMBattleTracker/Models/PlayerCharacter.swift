import Foundation
import SwiftData

enum CreatureSize: String, Codable, CaseIterable, Identifiable {
    case tiny = "Tiny"
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case huge = "Huge"
    case gargantuan = "Gargantuan"

    var id: String { rawValue }

    var carryMultiplier: Double {
        switch self {
        case .tiny: return 7.5
        case .small, .medium: return 15
        case .large: return 30
        case .huge: return 60
        case .gargantuan: return 120
        }
    }

    var heavyEncumbranceMultiplier: Double { carryMultiplier * 2 }
}

struct AltForm: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var maxHP: Int
    var armorClass: Int
    var isLinked: Bool = false
    var initiative: Int = 0
    var speed: Int = 30
    var flySpeed: Int = 0
    var swimSpeed: Int = 0
    var climbSpeed: Int = 0
    var burrowSpeed: Int = 0
    var canHover: Bool = false
    var strength: Int = 10
    var dexterity: Int = 10
    var constitution: Int = 10
    var intelligence: Int = 10
    var wisdom: Int = 10
    var charisma: Int = 10
    var saveProficiencies: [String: String] = [:]
    var damageResponses: [String: String] = [:]
    var conditionImmunities: [String] = []

    func abilityScore(for ability: Ability) -> Int {
        switch ability {
        case .strength: return strength
        case .dexterity: return dexterity
        case .constitution: return constitution
        case .intelligence: return intelligence
        case .wisdom: return wisdom
        case .charisma: return charisma
        }
    }

    func saveProficiency(for ability: Ability) -> SaveProficiency {
        SaveProficiency(rawValue: saveProficiencies[ability.rawValue] ?? "") ?? .none
    }

    mutating func setSaveProficiency(_ prof: SaveProficiency, for ability: Ability) {
        saveProficiencies[ability.rawValue] = prof.rawValue
    }

    func response(for type: DamageType) -> DamageResponse {
        DamageResponse(rawValue: damageResponses[type.rawValue] ?? "") ?? .regular
    }

    func isImmune(to condition: ConditionType) -> Bool {
        conditionImmunities.contains(condition.rawValue)
    }
}

struct InventoryItem: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var quantity: Int
    var weightPerUnit: Double
    var totalWeight: Double { Double(quantity) * weightPerUnit }
}

@Model
final class PlayerCharacter {
    var id: UUID
    var campaignID: UUID
    var name: String
    var playerName: String
    var combatSymbol: String = ""
    var currentHP: Int
    var maxHP: Int
    var armorClass: Int
    var gold: Int
    var silver: Int = 0
    var copper: Int = 0
    var level: Int
    var currentXP: Int
    var damageResponsesData: Data
    var resourcesData: Data
    var conditionImmunitiesData: Data = Data()
    var altFormsData: Data = Data()
    var strength: Int = 10
    var baseSpeed: Int = 30
    var flySpeed: Int = 0
    var swimSpeed: Int = 0
    var climbSpeed: Int = 0
    var burrowSpeed: Int = 0
    var inventoryData: Data = Data()
    var passivePerception: Int = 10
    var passiveInsight: Int = 10
    var passiveInvestigation: Int = 10
    var darkvisionRange: Int = 0
    var tempHP: Int = 0
    var sizeCategory: String = CreatureSize.medium.rawValue

    init(name: String, playerName: String = "", maxHP: Int, armorClass: Int, campaignID: UUID) {
        self.id = UUID()
        self.campaignID = campaignID
        self.name = name
        self.playerName = playerName
        self.maxHP = maxHP
        self.currentHP = maxHP
        self.armorClass = armorClass
        self.gold = 0
        self.level = 1
        self.currentXP = 0
        let defaults = Dictionary(uniqueKeysWithValues: DamageType.allCases.map { ($0.rawValue, DamageResponse.regular.rawValue) })
        self.damageResponsesData = (try? JSONEncoder().encode(defaults)) ?? Data()
        self.resourcesData = (try? JSONEncoder().encode([CharacterResource]())) ?? Data()
    }

    var displayName: String {
        playerName.isEmpty ? name : "\(playerName) (\(name))"
    }

    var damageResponses: [String: String] {
        get { (try? JSONDecoder().decode([String: String].self, from: damageResponsesData)) ?? [:] }
        set { damageResponsesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var resources: [CharacterResource] {
        get { (try? JSONDecoder().decode([CharacterResource].self, from: resourcesData)) ?? [] }
        set { resourcesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    func response(for type: DamageType) -> DamageResponse {
        DamageResponse(rawValue: damageResponses[type.rawValue] ?? "") ?? .regular
    }

    func setResponse(_ response: DamageResponse, for type: DamageType) {
        var r = damageResponses
        r[type.rawValue] = response.rawValue
        damageResponses = r
    }

    var conditionImmunities: [String] {
        get { (try? JSONDecoder().decode([String].self, from: conditionImmunitiesData)) ?? [] }
        set { conditionImmunitiesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    func isImmune(to condition: ConditionType) -> Bool {
        conditionImmunities.contains(condition.rawValue)
    }

    var altForms: [AltForm] {
        get { (try? JSONDecoder().decode([AltForm].self, from: altFormsData)) ?? [] }
        set { altFormsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var inventory: [InventoryItem] {
        get { (try? JSONDecoder().decode([InventoryItem].self, from: inventoryData)) ?? [] }
        set { inventoryData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var currentCarryWeight: Double {
        inventory.reduce(0) { $0 + $1.totalWeight }
    }

    var size: CreatureSize {
        get { CreatureSize(rawValue: sizeCategory) ?? .medium }
        set { sizeCategory = newValue.rawValue }
    }

    var maxCarryWeight: Double { Double(strength) * size.carryMultiplier }

    var effectiveSpeed: Int {
        if currentCarryWeight > Double(strength) * size.heavyEncumbranceMultiplier { return 0 }
        if currentCarryWeight > maxCarryWeight { return 5 }
        return baseSpeed
    }

    var xpForNextLevel: Int? {
        ChallengeRating.xpForNextLevel(afterLevel: level)
    }

    var xpProgressInCurrentLevel: Double {
        let currentLevelXP = ChallengeRating.xpForLevel(level)
        guard let nextLevelXP = xpForNextLevel, nextLevelXP > currentLevelXP else { return 1.0 }
        let progress = Double(currentXP - currentLevelXP) / Double(nextLevelXP - currentLevelXP)
        return max(0, min(1, progress))
    }
}
