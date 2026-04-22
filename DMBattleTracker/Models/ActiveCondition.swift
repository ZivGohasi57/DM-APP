import Foundation

struct ActiveCondition: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var conditionType: ConditionType
    var durationRounds: Int?
    var exhaustionLevel: Int = 1
    var endOnSave: Bool = false

    var displayDuration: String {
        guard let d = durationRounds else { return "∞" }
        return "\(d)R"
    }

    static var saveConditions: Set<ConditionType> {
        [.blinded, .charmed, .deafened, .frightened, .paralyzed, .poisoned, .restrained, .stunned]
    }
}
