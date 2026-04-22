import Foundation
import Observation
import SwiftUI

@Observable
final class Combatant: Identifiable {
    var id: UUID = UUID()
    var name: String
    var currentHP: Int
    var maxHP: Int
    var tempHP: Int = 0
    var initiative: Int
    var armorClass: Int
    var damageResponsesDict: [String: String]
    var isPC: Bool
    var isSelected: Bool = false
    var isCurrentTurn: Bool = false
    var conditions: [ActiveCondition] = []
    var resources: [CharacterResource] = []
    var pcID: UUID? = nil
    var hpFormula: String = ""
    var hasEnteredCombat: Bool = true
    var nickname: String = ""
    var playerName: String = ""
    var strength: Int = 10
    var dexterity: Int = 10
    var constitution: Int = 10
    var intelligence: Int = 10
    var wisdom: Int = 10
    var charisma: Int = 10
    var challengeRatingValue: String = ChallengeRating.zero.rawValue
    var saveProficiencies: [String: String] = [:]
    var conditionImmunities: [String] = []
    var isNPC: Bool = false
    var altForms: [AltForm] = []
    var altFormActive: Bool = false
    var altFormName: String = ""
    var altFormDurationRounds: Int? = nil
    var altFormIsLinked: Bool = false
    var originalName: String = ""
    var originalMaxHP: Int = 0
    var originalCurrentHP: Int = 0
    var originalArmorClass: Int = 0
    var originalStrength: Int = 10
    var originalDexterity: Int = 10
    var originalConstitution: Int = 10
    var originalIntelligence: Int = 10
    var originalWisdom: Int = 10
    var originalCharisma: Int = 10
    var originalSpeed: Int = 30
    var originalFlySpeed: Int = 0
    var originalSwimSpeed: Int = 0
    var originalClimbSpeed: Int = 0
    var originalBurrowSpeed: Int = 0
    var originalCanHover: Bool = false
    var originalDamageResponses: [String: String] = [:]
    var originalConditionImmunities: [String] = []
    var originalSaveProficiencies: [String: String] = [:]
    var acBonus: Int = 0
    var acBonusDuration: Int? = nil
    var deathSaveSuccesses: Int = 0
    var deathSaveFailures: Int = 0
    var isStabilized: Bool = false
    var isConcentrating: Bool = false
    var concentrationSpellName: String = ""
    var needsConcentrationCheck: Bool = false
    var speed: Int = 30
    var flySpeed: Int = 0
    var swimSpeed: Int = 0
    var climbSpeed: Int = 0
    var burrowSpeed: Int = 0
    var canHover: Bool = false

    init(
        name: String,
        currentHP: Int,
        maxHP: Int,
        initiative: Int,
        armorClass: Int,
        damageResponsesDict: [String: String],
        isPC: Bool
    ) {
        self.name = name
        self.currentHP = currentHP
        self.maxHP = maxHP
        self.initiative = initiative
        self.armorClass = armorClass
        self.damageResponsesDict = damageResponsesDict
        self.isPC = isPC
    }

    static func fromPC(_ pc: PlayerCharacter, initiative: Int) -> Combatant {
        let c = Combatant(
            name: pc.name,
            currentHP: pc.currentHP,
            maxHP: pc.maxHP,
            initiative: initiative,
            armorClass: pc.armorClass,
            damageResponsesDict: pc.damageResponses,
            isPC: true
        )
        c.resources = pc.resources
        c.tempHP = pc.tempHP
        c.pcID = pc.id
        c.playerName = pc.playerName
        c.nickname = pc.combatSymbol
        c.conditionImmunities = pc.conditionImmunities
        c.altForms = pc.altForms
        c.strength = pc.strength
        c.speed = pc.effectiveSpeed
        c.flySpeed = pc.flySpeed
        c.swimSpeed = pc.swimSpeed
        c.climbSpeed = pc.climbSpeed
        c.burrowSpeed = pc.burrowSpeed
        return c
    }

    static func fromTemplate(_ template: MonsterTemplate, suffix: String = "", initiative: Int? = nil) -> Combatant {
        let finalName = suffix.isEmpty ? template.name : "\(template.name) \(suffix)"
        let c = Combatant(
            name: finalName,
            currentHP: template.maxHP,
            maxHP: template.maxHP,
            initiative: initiative ?? template.initiative,
            armorClass: template.armorClass,
            damageResponsesDict: template.damageResponses,
            isPC: false
        )
        c.hpFormula = template.hpFormula
        c.strength = template.strength
        c.dexterity = template.dexterity
        c.constitution = template.constitution
        c.intelligence = template.intelligence
        c.wisdom = template.wisdom
        c.charisma = template.charisma
        c.challengeRatingValue = template.challengeRatingValue
        c.saveProficiencies = template.saveProficiencies
        c.conditionImmunities = template.conditionImmunities
        c.speed = template.speed
        c.flySpeed = template.flySpeed
        c.swimSpeed = template.swimSpeed
        c.climbSpeed = template.climbSpeed
        c.burrowSpeed = template.burrowSpeed
        c.canHover = template.canHover
        return c
    }

    static func fromNPCTemplate(_ template: NPCTemplate, initiative: Int? = nil) -> Combatant {
        let c = Combatant(
            name: template.name,
            currentHP: template.maxHP,
            maxHP: template.maxHP,
            initiative: initiative ?? template.initiative,
            armorClass: template.armorClass,
            damageResponsesDict: template.damageResponses,
            isPC: false
        )
        c.isNPC = true
        c.conditionImmunities = template.conditionImmunities
        c.speed = template.speed
        c.flySpeed = template.flySpeed
        c.swimSpeed = template.swimSpeed
        c.climbSpeed = template.climbSpeed
        c.burrowSpeed = template.burrowSpeed
        c.canHover = template.canHover
        c.strength = template.strength
        c.dexterity = template.dexterity
        c.constitution = template.constitution
        c.intelligence = template.intelligence
        c.wisdom = template.wisdom
        c.charisma = template.charisma
        c.saveProficiencies = template.saveProficiencies
        return c
    }

    var challengeRating: ChallengeRating {
        ChallengeRating(rawValue: challengeRatingValue) ?? .zero
    }

    var encounterXP: Int {
        (isPC || isNPC) ? 0 : challengeRating.xp
    }

    func response(for type: DamageType) -> DamageResponse {
        DamageResponse(rawValue: damageResponsesDict[type.rawValue] ?? "") ?? .regular
    }

    var effectiveAC: Int { armorClass + acBonus }

    func applyDamage(_ rawAmount: Int, type: DamageType) {
        let r = response(for: type)
        var finalDamage: Int
        switch r {
        case .immune: finalDamage = 0
        case .resistant: finalDamage = rawAmount / 2
        case .vulnerable: finalDamage = rawAmount * 2
        case .regular: finalDamage = rawAmount
        }
        if tempHP > 0 {
            let absorbed = min(tempHP, finalDamage)
            tempHP -= absorbed
            finalDamage -= absorbed
        }
        if finalDamage > 0 {
            conditions.removeAll { $0.conditionType == .unconscious }
        }
        if isConcentrating && finalDamage > 0 { needsConcentrationCheck = true }
        if altFormActive && finalDamage > currentHP {
            let overflow = finalDamage - currentHP
            currentHP = 0
            revertAltForm()
            let adjustedOverflow: Int
            switch response(for: type) {
            case .immune: adjustedOverflow = 0
            case .resistant: adjustedOverflow = overflow / 2
            case .vulnerable: adjustedOverflow = overflow * 2
            case .regular: adjustedOverflow = overflow
            }
            currentHP = max(0, currentHP - adjustedOverflow)
        } else {
            currentHP = max(0, currentHP - finalDamage)
            if isDead && altFormActive { revertAltForm() }
        }
    }

    func applyTempHP(_ amount: Int) {
        if amount > tempHP {
            tempHP = amount
        }
    }

    func applyHPDelta(_ text: String) {
        guard let delta = Int(text) else { return }
        let wasDown = currentHP <= 0
        let prevHP = currentHP
        currentHP = max(0, min(maxHP, currentHP + delta))
        if isConcentrating && delta < 0 && currentHP < prevHP { needsConcentrationCheck = true }
        if wasDown && currentHP > 0 {
            deathSaveSuccesses = 0
            deathSaveFailures = 0
            isStabilized = false
            conditions.removeAll { $0.conditionType == .unconscious }
        }
        if isDead && altFormActive { revertAltForm() }
    }

    func resetHP() {
        currentHP = maxHP
        tempHP = 0
    }

    func isImmune(to condition: ConditionType) -> Bool {
        conditionImmunities.contains(condition.rawValue)
    }

    func activateAltForm(_ form: AltForm) {
        originalName = name
        originalMaxHP = maxHP
        originalCurrentHP = currentHP
        originalArmorClass = armorClass
        originalStrength = strength
        originalDexterity = dexterity
        originalConstitution = constitution
        originalIntelligence = intelligence
        originalWisdom = wisdom
        originalCharisma = charisma
        originalSpeed = speed
        originalFlySpeed = flySpeed
        originalSwimSpeed = swimSpeed
        originalClimbSpeed = climbSpeed
        originalBurrowSpeed = burrowSpeed
        originalCanHover = canHover
        originalDamageResponses = damageResponsesDict
        originalConditionImmunities = conditionImmunities
        originalSaveProficiencies = saveProficiencies

        altFormIsLinked = form.isLinked
        altFormName = form.name
        name = form.name
        maxHP = form.maxHP
        currentHP = form.isLinked ? min(originalCurrentHP, form.maxHP) : form.maxHP
        armorClass = form.armorClass
        strength = form.strength
        dexterity = form.dexterity
        constitution = form.constitution
        intelligence = form.intelligence
        wisdom = form.wisdom
        charisma = form.charisma
        speed = form.speed
        flySpeed = form.flySpeed
        swimSpeed = form.swimSpeed
        climbSpeed = form.climbSpeed
        burrowSpeed = form.burrowSpeed
        canHover = form.canHover
        if !form.damageResponses.isEmpty { damageResponsesDict = form.damageResponses }
        if !form.conditionImmunities.isEmpty { conditionImmunities = form.conditionImmunities }
        if !form.saveProficiencies.isEmpty { saveProficiencies = form.saveProficiencies }
        altFormActive = true
    }

    func revertAltForm() {
        name = originalName
        maxHP = originalMaxHP
        currentHP = altFormIsLinked ? min(currentHP, originalMaxHP) : originalCurrentHP
        armorClass = originalArmorClass
        strength = originalStrength
        dexterity = originalDexterity
        constitution = originalConstitution
        intelligence = originalIntelligence
        wisdom = originalWisdom
        charisma = originalCharisma
        speed = originalSpeed
        flySpeed = originalFlySpeed
        swimSpeed = originalSwimSpeed
        climbSpeed = originalClimbSpeed
        burrowSpeed = originalBurrowSpeed
        canHover = originalCanHover
        damageResponsesDict = originalDamageResponses
        conditionImmunities = originalConditionImmunities
        saveProficiencies = originalSaveProficiencies
        altFormActive = false
        altFormName = ""
        altFormDurationRounds = nil
        altFormIsLinked = false
        originalName = ""
    }

    func addCondition(_ type: ConditionType, duration: Int?, exhaustionLevel: Int = 1, endOnSave: Bool = false) {
        guard !isImmune(to: type) else { return }
        if let idx = conditions.firstIndex(where: { $0.conditionType == type }) {
            if type == .exhaustion {
                conditions[idx].exhaustionLevel = min(6, conditions[idx].exhaustionLevel + 1)
            }
            return
        }
        var cond = ActiveCondition(conditionType: type, durationRounds: duration)
        cond.exhaustionLevel = exhaustionLevel
        cond.endOnSave = endOnSave
        conditions.append(cond)
    }

    func removeCondition(id: UUID) {
        conditions.removeAll { $0.id == id }
    }

    func decrementConditionDuration(id: UUID) {
        guard let idx = conditions.firstIndex(where: { $0.id == id }) else { return }
        if let d = conditions[idx].durationRounds {
            if d <= 1 {
                conditions.remove(at: idx)
            } else {
                conditions[idx].durationRounds = d - 1
            }
        }
    }

    func decrementAllConditionDurations() {
        conditions = conditions.compactMap { c in
            var updated = c
            guard let d = updated.durationRounds else { return updated }
            let newD = d - 1
            if newD <= 0 { return nil }
            updated.durationRounds = newD
            return updated
        }
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

    func savingThrowModifier(for ability: Ability) -> Int {
        let score = abilityScore(for: ability)
        let baseMod = Combatant.abilityModifier(score)
        let profRaw = saveProficiencies[ability.rawValue] ?? SaveProficiency.none.rawValue
        let prof = SaveProficiency(rawValue: profRaw) ?? .none
        return baseMod + challengeRating.proficiencyBonus * prof.multiplier
    }

    func saveProficiency(for ability: Ability) -> SaveProficiency {
        SaveProficiency(rawValue: saveProficiencies[ability.rawValue] ?? "") ?? .none
    }

    static func abilityModifier(_ score: Int) -> Int {
        (score - 10) >> 1
    }

    static func formattedModifier(_ score: Int) -> String {
        let mod = abilityModifier(score)
        return mod >= 0 ? "+\(mod)" : "\(mod)"
    }

    var displayName: String {
        nickname.isEmpty ? name : "\(nickname) (\(name))"
    }

    var hpPercentage: Double {
        guard maxHP > 0 else { return 0 }
        return Double(currentHP) / Double(maxHP)
    }

    var hpBarColor: Color {
        if hpPercentage > 0.5 { return .green }
        if hpPercentage > 0.25 { return .yellow }
        if hpPercentage > 0 { return .red }
        return .gray
    }

    var isDead: Bool { currentHP <= 0 }

    var hasSkipCondition: Bool {
        conditions.contains {
            [ConditionType.incapacitated, .paralyzed, .stunned, .unconscious, .petrified].contains($0.conditionType)
        }
    }
}
