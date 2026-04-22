import Foundation
import SwiftData

@Model final class GalleryImage {
    var id: UUID
    var campaignID: UUID
    var folderID: UUID
    var title: String
    var imageData: Data
    var sortOrder: Int
    var createdAt: Date

    init(folderID: UUID, campaignID: UUID, imageData: Data, title: String = "", sortOrder: Int = 0) {
        self.id = UUID()
        self.campaignID = campaignID
        self.folderID = folderID
        self.title = title
        self.imageData = imageData
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
