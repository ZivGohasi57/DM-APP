import Foundation
import Observation

struct PendingSave: Identifiable, Equatable {
    var id: UUID = UUID()
    var combatantID: UUID
    var combatantName: String
    var conditionID: UUID
    var conditionName: String
}

struct PCXPResult: Identifiable {
    var id: UUID
    var name: String
    var xpGained: Int
    var oldXP: Int
    var newXP: Int
    var oldLevel: Int
    var newLevel: Int
    var didLevelUp: Bool { newLevel > oldLevel }
}

struct PostCombatSummary {
    var totalEnemyXP: Int
    var pcResults: [PCXPResult]
    var trackXP: Bool = true
    var anyLevelUp: Bool { trackXP && pcResults.contains { $0.didLevelUp } }
}

@Observable
final class CombatEngine {
    var combatants: [Combatant] = []
    var currentTurnIndex: Int = 0
    var currentRound: Int = 1
    var isCombatActive: Bool = false
    var activeEncounterID: UUID? = nil
    var firstStrikerID: UUID? = nil
    var firstStrikerHasGone: Bool = true
    var aoeAmountText: String = ""
    var pendingSaves: [PendingSave] = []

    var activeCombatant: Combatant? {
        guard isCombatActive, combatants.indices.contains(currentTurnIndex) else { return nil }
        return combatants[currentTurnIndex]
    }

    var selectedCombatants: [Combatant] {
        combatants.filter { $0.isSelected }
    }

    var totalEnemyXP: Int {
        combatants.filter { !$0.isPC && !$0.isNPC && $0.isDead }.reduce(0) { $0 + $1.encounterXP }
    }

    func startCombat(combatants: [Combatant], firstStrikerID: UUID?) {
        for c in self.combatants { c.isCurrentTurn = false; c.isSelected = false }
        self.combatants = combatants.sorted { $0.initiative > $1.initiative }
        self.firstStrikerID = firstStrikerID
        self.firstStrikerHasGone = firstStrikerID == nil
        self.currentRound = 1
        self.isCombatActive = true

        if let fID = firstStrikerID, let idx = self.combatants.firstIndex(where: { $0.id == fID }) {
            self.currentTurnIndex = idx
        } else {
            self.currentTurnIndex = self.combatants.firstIndex(where: { $0.hasEnteredCombat }) ?? 0
        }

        if !self.combatants.isEmpty {
            self.combatants[currentTurnIndex].isCurrentTurn = true
        }
    }

    func nextTurn() {
        guard isCombatActive, !combatants.isEmpty else { return }

        let cur = combatants[currentTurnIndex]
        cur.isCurrentTurn = false
        let saveConds = cur.conditions.filter { $0.endOnSave }
        cur.decrementAllConditionDurations()
        for cond in saveConds where cur.conditions.contains(where: { $0.id == cond.id }) {
            pendingSaves.append(PendingSave(
                combatantID: cur.id,
                combatantName: cur.name,
                conditionID: cond.id,
                conditionName: cond.conditionType.rawValue
            ))
        }
        if let dur = cur.acBonusDuration {
            if dur <= 1 {
                cur.acBonus = 0
                cur.acBonusDuration = nil
            } else {
                cur.acBonusDuration = dur - 1
            }
        }
        if let dur = cur.altFormDurationRounds {
            if dur <= 1 {
                cur.altFormDurationRounds = nil
                if cur.altFormActive { cur.revertAltForm() }
            } else {
                cur.altFormDurationRounds = dur - 1
            }
        }

        let count = combatants.count
        var nextIndex: Int

        if !firstStrikerHasGone {
            firstStrikerHasGone = true
            nextIndex = 0
            if let fID = firstStrikerID, combatants[0].id == fID {
                nextIndex = 1
                if nextIndex >= count {
                    currentRound += 1
                    nextIndex = 0
                }
            }
        } else {
            nextIndex = currentTurnIndex + 1
            if currentRound == 1, let fID = firstStrikerID,
               nextIndex < count, combatants[nextIndex].id == fID {
                nextIndex += 1
            }
            if nextIndex >= count {
                nextIndex = 0
                currentRound += 1
            }
        }

        var skips = 0
        while skips < combatants.count && (!combatants[nextIndex].hasEnteredCombat || combatants[nextIndex].isDead || combatants[nextIndex].hasSkipCondition) {
            let c = combatants[nextIndex]
            if c.hasEnteredCombat && !c.isDead && c.hasSkipCondition {
                c.decrementAllConditionDurations()
            }
            nextIndex = (nextIndex + 1) % combatants.count
            skips += 1
        }

        currentTurnIndex = nextIndex
        combatants[currentTurnIndex].isCurrentTurn = true
    }

    func prevTurn() {
        guard isCombatActive, !combatants.isEmpty else { return }
        combatants[currentTurnIndex].isCurrentTurn = false
        var prevIndex = (currentTurnIndex - 1 + combatants.count) % combatants.count
        if prevIndex >= currentTurnIndex, currentRound > 1 { currentRound -= 1 }
        var skips = 0
        while skips < combatants.count && (!combatants[prevIndex].hasEnteredCombat || combatants[prevIndex].isDead) {
            prevIndex = (prevIndex - 1 + combatants.count) % combatants.count
            skips += 1
        }
        currentTurnIndex = prevIndex
        combatants[currentTurnIndex].isCurrentTurn = true
    }

    func applyAOE(isSubtract: Bool) {
        guard let amount = Int(aoeAmountText), amount > 0 else {
            aoeAmountText = ""
            return
        }
        for combatant in combatants where combatant.isSelected {
            if isSubtract {
                combatant.currentHP = max(0, combatant.currentHP - amount)
            } else {
                combatant.currentHP = min(combatant.maxHP, combatant.currentHP + amount)
            }
        }
        aoeAmountText = ""
    }

    func buildPostCombatSummary(allPCs: [PlayerCharacter], trackXP: Bool = true) -> PostCombatSummary {
        let xp = trackXP ? totalEnemyXP : 0
        var results: [PCXPResult] = []
        for combatant in combatants where combatant.isPC {
            guard let pcID = combatant.pcID,
                  let pc = allPCs.first(where: { $0.id == pcID }) else { continue }
            let oldXP = pc.currentXP
            let oldLevel = pc.level
            let newXP = trackXP ? oldXP + xp : oldXP
            let newLevel = trackXP ? ChallengeRating.levelForXP(newXP) : oldLevel
            results.append(PCXPResult(
                id: pcID,
                name: pc.name,
                xpGained: xp,
                oldXP: oldXP,
                newXP: newXP,
                oldLevel: oldLevel,
                newLevel: newLevel
            ))
        }
        return PostCombatSummary(totalEnemyXP: xp, pcResults: results, trackXP: trackXP)
    }

    func endCombat() {
        isCombatActive = false
        activeEncounterID = nil
        for c in combatants {
            c.isCurrentTurn = false
            c.isSelected = false
        }
        combatants = []
        currentTurnIndex = 0
        currentRound = 1
        firstStrikerID = nil
        firstStrikerHasGone = true
        aoeAmountText = ""
        pendingSaves = []
    }

    var roundTimeDescription: String {
        let seconds = (currentRound - 1) * 6
        if seconds == 0 { return "Combat start" }
        if seconds < 60 { return "\(seconds)s elapsed" }
        let minutes = seconds / 60
        let rem = seconds % 60
        if rem == 0 { return "\(minutes)m elapsed" }
        return "\(minutes)m \(rem)s elapsed"
    }
}
