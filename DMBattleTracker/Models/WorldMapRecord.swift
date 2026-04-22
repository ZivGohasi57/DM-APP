import Foundation
import SwiftData

@Model final class WorldMapRecord {
    var id: UUID
    var campaignID: UUID
    var imageData: Data?

    init(campaignID: UUID) {
        self.id = UUID()
        self.campaignID = campaignID
    }
}
