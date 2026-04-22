import Foundation
import SwiftData

@Model
final class NPCTemplate {
    var id: UUID
    var campaignID: UUID
    var name: String
    var maxHP: Int
    var hpFormula: String = ""
    var initiative: Int
    var armorClass: Int
    var damageResponsesData: Data
    var conditionImmunitiesData: Data = Data()
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
    var saveProficienciesData: Data = Data()

    init(name: String, maxHP: Int, hpFormula: String = "", initiative: Int = 0, armorClass: Int, campaignID: UUID) {
        self.id = UUID()
        self.campaignID = campaignID
        self.name = name
        self.maxHP = maxHP
        self.hpFormula = hpFormula
        self.initiative = initiative
        self.armorClass = armorClass
        let defaults = Dictionary(uniqueKeysWithValues: DamageType.allCases.map { ($0.rawValue, DamageResponse.regular.rawValue) })
        self.damageResponsesData = (try? JSONEncoder().encode(defaults)) ?? Data()
        self.saveProficienciesData = (try? JSONEncoder().encode([String: String]())) ?? Data()
        self.speed = 30
    }

    var damageResponses: [String: String] {
        get { (try? JSONDecoder().decode([String: String].self, from: damageResponsesData)) ?? [:] }
        set { damageResponsesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var saveProficiencies: [String: String] {
        get { (try? JSONDecoder().decode([String: String].self, from: saveProficienciesData)) ?? [:] }
        set { saveProficienciesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var conditionImmunities: [String] {
        get { (try? JSONDecoder().decode([String].self, from: conditionImmunitiesData)) ?? [] }
        set { conditionImmunitiesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    func response(for type: DamageType) -> DamageResponse {
        DamageResponse(rawValue: damageResponses[type.rawValue] ?? "") ?? .regular
    }

    func isImmune(to condition: ConditionType) -> Bool {
        conditionImmunities.contains(condition.rawValue)
    }

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

    func setSaveProficiency(_ prof: SaveProficiency, for ability: Ability) {
        var profs = saveProficiencies
        profs[ability.rawValue] = prof.rawValue
        saveProficiencies = profs
    }
}
