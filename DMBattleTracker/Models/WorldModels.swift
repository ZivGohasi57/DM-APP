import Foundation
import SwiftData

@Model final class Country {
    var id: UUID
    var campaignID: UUID
    var name: String
    var sortOrder: Int
    var isMapObtained: Bool = false
    var mapImageData: Data?

    init(name: String, campaignID: UUID, sortOrder: Int = 0) {
        self.id = UUID()
        self.campaignID = campaignID
        self.name = name
        self.sortOrder = sortOrder
    }
}

@Model final class City {
    var id: UUID
    var campaignID: UUID
    var countryID: UUID
    var name: String
    var mapImageData: Data?
    var symbolImageData: Data?
    var cityDescription: String = ""
    var isMapObtained: Bool = false

    init(name: String, campaignID: UUID, countryID: UUID) {
        self.id = UUID()
        self.campaignID = campaignID
        self.countryID = countryID
        self.name = name
    }
}

@Model final class StoryPin {
    var id: UUID
    var cityID: UUID
    var storyID: UUID
    var xPosition: Double
    var yPosition: Double

    init(cityID: UUID, storyID: UUID, x: Double, y: Double) {
        self.id = UUID()
        self.cityID = cityID
        self.storyID = storyID
        self.xPosition = x
        self.yPosition = y
    }
}

@Model final class ShopPin {
    var id: UUID
    var cityID: UUID
    var shopID: UUID
    var xPosition: Double
    var yPosition: Double

    init(cityID: UUID, shopID: UUID, x: Double, y: Double) {
        self.id = UUID()
        self.cityID = cityID
        self.shopID = shopID
        self.xPosition = x
        self.yPosition = y
    }
}
