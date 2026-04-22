import Foundation
import SwiftData

@Model final class GalleryFolder {
    var id: UUID
    var campaignID: UUID
    var name: String
    var sortOrder: Int
    var isBuiltIn: Bool

    init(name: String, campaignID: UUID, sortOrder: Int, isBuiltIn: Bool = false) {
        self.id = UUID()
        self.campaignID = campaignID
        self.name = name
        self.sortOrder = sortOrder
        self.isBuiltIn = isBuiltIn
    }
}
