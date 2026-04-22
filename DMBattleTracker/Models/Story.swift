import Foundation
import SwiftData

enum StoryStatus: String, CaseIterable, Identifiable {
    case active = "Active"
    case completed = "Completed"
    case failed = "Failed"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .active: return "circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .active: return .orange
        case .completed: return .green
        case .failed: return Color(red: 0.85, green: 0.2, blue: 0.2)
        }
    }
}

import SwiftUI

struct StoryNPCEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var npcID: UUID
    var npcName: String
}

struct StoryEncounterEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var encounterID: UUID
    var encounterName: String
    var isCompleted: Bool = false
}

@Model final class Story {
    var id: UUID
    var campaignID: UUID
    var name: String
    var level: Int
    var storyDescription: String
    var isCompleted: Bool
    var isFailed: Bool = false
    var isMainQuest: Bool = true
    var rewardXP: Int = 0
    var xpAwarded: Bool = false
    var npcEntriesData: Data
    var prerequisiteStoryIDsData: Data = Data()
    var locationCityID: UUID? = nil
    var linkedEncountersData: Data = Data()

    init(name: String, campaignID: UUID) {
        self.id = UUID()
        self.campaignID = campaignID
        self.name = name
        self.level = 1
        self.storyDescription = ""
        self.isCompleted = false
        self.npcEntriesData = (try? JSONEncoder().encode([StoryNPCEntry]())) ?? Data()
    }

    var prerequisiteStoryIDs: [UUID] {
        get { (try? JSONDecoder().decode([UUID].self, from: prerequisiteStoryIDsData)) ?? [] }
        set { prerequisiteStoryIDsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var status: StoryStatus {
        get {
            if isFailed { return .failed }
            if isCompleted { return .completed }
            return .active
        }
        set {
            switch newValue {
            case .active:    isCompleted = false; isFailed = false
            case .completed: isCompleted = true;  isFailed = false
            case .failed:    isCompleted = false; isFailed = true
            }
        }
    }

    var npcEntries: [StoryNPCEntry] {
        get { (try? JSONDecoder().decode([StoryNPCEntry].self, from: npcEntriesData)) ?? [] }
        set { npcEntriesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var linkedEncounters: [StoryEncounterEntry] {
        get { (try? JSONDecoder().decode([StoryEncounterEntry].self, from: linkedEncountersData)) ?? [] }
        set { linkedEncountersData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var linkedItemsData: Data = Data()

    var linkedItems: [StoryItemEntry] {
        get { (try? JSONDecoder().decode([StoryItemEntry].self, from: linkedItemsData)) ?? [] }
        set { linkedItemsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    func setLinkedItems(_ items: [StoryItemEntry]) {
        linkedItemsData = (try? JSONEncoder().encode(items)) ?? Data()
    }
}
