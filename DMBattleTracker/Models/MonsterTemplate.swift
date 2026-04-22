import Foundation
import SwiftData

@Model
final class MonsterTemplate {
    var id: UUID
    var campaignID: UUID
    var isGlobal: Bool
    var name: String
    var maxHP: Int
    var hpFormula: String
    var initiative: Int
    var armorClass: Int
    var damageResponsesData: Data
    var strength: Int
    var dexterity: Int
    var constitution: Int
    var intelligence: Int
    var wisdom: Int
    var charisma: Int
    var challengeRatingValue: String
    var saveProficienciesData: Data
    var conditionImmunitiesData: Data = Data()
    var speed: Int = 30
    var flySpeed: Int = 0
    var swimSpeed: Int = 0
    var climbSpeed: Int = 0
    var burrowSpeed: Int = 0
    var canHover: Bool = false

    init(name: String, maxHP: Int, hpFormula: String = "", initiative: Int, armorClass: Int, campaignID: UUID, isGlobal: Bool = false) {
        self.id = UUID()
        self.campaignID = campaignID
        self.isGlobal = isGlobal
        self.name = name
        self.maxHP = maxHP
        self.hpFormula = hpFormula
        self.initiative = initiative
        self.armorClass = armorClass
        let defaults = Dictionary(uniqueKeysWithValues: DamageType.allCases.map { ($0.rawValue, DamageResponse.regular.rawValue) })
        self.damageResponsesData = (try? JSONEncoder().encode(defaults)) ?? Data()
        self.strength = 10
        self.dexterity = 10
        self.constitution = 10
        self.intelligence = 10
        self.wisdom = 10
        self.charisma = 10
        self.challengeRatingValue = ChallengeRating.zero.rawValue
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

    func isImmune(to condition: ConditionType) -> Bool {
        conditionImmunities.contains(condition.rawValue)
    }

    var challengeRating: ChallengeRating {
        get { ChallengeRating(rawValue: challengeRatingValue) ?? .zero }
        set { challengeRatingValue = newValue.rawValue }
    }

    func response(for type: DamageType) -> DamageResponse {
        DamageResponse(rawValue: damageResponses[type.rawValue] ?? "") ?? .regular
    }

    func setResponse(_ response: DamageResponse, for type: DamageType) {
        var r = damageResponses
        r[type.rawValue] = response.rawValue
        damageResponses = r
    }

    func saveProficiency(for ability: Ability) -> SaveProficiency {
        SaveProficiency(rawValue: saveProficiencies[ability.rawValue] ?? "") ?? .none
    }

    func setSaveProficiency(_ prof: SaveProficiency, for ability: Ability) {
        var profs = saveProficiencies
        profs[ability.rawValue] = prof.rawValue
        saveProficiencies = profs
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
}
