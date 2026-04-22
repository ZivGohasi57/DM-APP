import Foundation
import SwiftData

@Model
final class Campaign {
    var id: UUID
    var name: String
    var createdAt: Date
    var trackXP: Bool = true
    var defaultHPMode: String = "Average"
    var autoRollInitiative: Bool = true

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}
