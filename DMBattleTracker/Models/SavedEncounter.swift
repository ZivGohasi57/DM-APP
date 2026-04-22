import Foundation
import SwiftData

struct EncounterPCEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var pcID: UUID
    var pcName: String
}

struct EncounterMonsterEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var templateID: UUID
    var templateName: String
    var count: Int
}

struct EncounterNPCEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var npcID: UUID
    var npcName: String
}

@Model
final class EncounterFolder {
    var id: UUID
    var campaignID: UUID
    var name: String
    var sortOrder: Int = 0

    init(name: String, campaignID: UUID, sortOrder: Int = 0) {
        self.id = UUID()
        self.campaignID = campaignID
        self.name = name
        self.sortOrder = sortOrder
    }
}

@Model
final class SavedEncounter {
    var id: UUID
    var campaignID: UUID
    var name: String
    var folderID: UUID? = nil
    var pcEntriesData: Data
    var monsterEntriesData: Data
    var npcEntriesData: Data = Data()
    var mapImageData: Data? = nil

    init(name: String, campaignID: UUID) {
        self.id = UUID()
        self.campaignID = campaignID
        self.name = name
        self.pcEntriesData = (try? JSONEncoder().encode([EncounterPCEntry]())) ?? Data()
        self.monsterEntriesData = (try? JSONEncoder().encode([EncounterMonsterEntry]())) ?? Data()
        self.npcEntriesData = (try? JSONEncoder().encode([EncounterNPCEntry]())) ?? Data()
    }

    var pcEntries: [EncounterPCEntry] {
        get { (try? JSONDecoder().decode([EncounterPCEntry].self, from: pcEntriesData)) ?? [] }
        set { pcEntriesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var monsterEntries: [EncounterMonsterEntry] {
        get { (try? JSONDecoder().decode([EncounterMonsterEntry].self, from: monsterEntriesData)) ?? [] }
        set { monsterEntriesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var npcEntries: [EncounterNPCEntry] {
        get { (try? JSONDecoder().decode([EncounterNPCEntry].self, from: npcEntriesData)) ?? [] }
        set { npcEntriesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}
