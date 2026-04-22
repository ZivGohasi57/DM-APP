import Foundation
import SwiftUI
import SwiftData

enum WishlistPriority: Int, Codable, CaseIterable {
    case high = 0
    case medium = 1
    case low = 2

    var label: String {
        switch self {
        case .high: return "High Priority"
        case .medium: return "Medium Priority"
        case .low: return "Low Priority"
        }
    }

    var shortLabel: String {
        switch self {
        case .high: return "High"
        case .medium: return "Med"
        case .low: return "Low"
        }
    }

    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

@Model final class PCWishlistItem {
    var id: UUID = UUID()
    var pcID: UUID
    var campaignID: UUID
    var slug: String
    var name: String
    var itemTypeRaw: String
    var priorityRaw: Int
    var notes: String
    var acquired: Bool
    var addedAt: Date

    init(pcID: UUID, campaignID: UUID, item: CatalogItem, priority: WishlistPriority = .medium) {
        self.id = UUID()
        self.pcID = pcID
        self.campaignID = campaignID
        self.slug = item.slug
        self.name = item.name
        self.itemTypeRaw = item.type.rawValue
        self.priorityRaw = priority.rawValue
        self.notes = ""
        self.acquired = false
        self.addedAt = Date()
    }

    var itemType: CatalogItemType { CatalogItemType(rawValue: itemTypeRaw) ?? .magicItem }

    var priority: WishlistPriority {
        get { WishlistPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }
}

struct WishlistAvailability {
    let countryName: String
    let cityName: String
    let shopName: String
    let price: String
    let shopID: UUID
}
