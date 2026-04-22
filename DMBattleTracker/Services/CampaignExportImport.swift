import Foundation
import SwiftData

// MARK: - Top-level bundle

struct CampaignBundle: Codable {
    var version: Int = 2
    var campaign: CampaignDTO
    var players: [PlayerCharacterDTO]
    var npcs: [NPCTemplateDTO]
    var monsters: [MonsterTemplateDTO]
    var encounterFolders: [EncounterFolderDTO]
    var encounters: [SavedEncounterDTO]
    var countries: [CountryDTO]
    var cities: [CityDTO]
    var storyPins: [StoryPinDTO]
    var shopPins: [ShopPinDTO] = []
    var stories: [StoryDTO]
    var shops: [ShopDTO] = []
    var customCatalogItems: [CustomCatalogItemDTO] = []
    var wishlistItems: [PCWishlistItemDTO] = []
    var worldMap: WorldMapRecordDTO?
    var galleryFolders: [GalleryFolderDTO]
    var galleryImages: [GalleryImageDTO]
}

// MARK: - DTOs

struct CampaignDTO: Codable {
    var id: UUID; var name: String; var createdAt: Date; var trackXP: Bool; var defaultHPMode: String

    init(_ m: Campaign) {
        id = m.id; name = m.name; createdAt = m.createdAt
        trackXP = m.trackXP; defaultHPMode = m.defaultHPMode
    }
}

struct PlayerCharacterDTO: Codable {
    var id: UUID; var campaignID: UUID; var name: String; var playerName: String; var combatSymbol: String
    var currentHP: Int; var maxHP: Int; var armorClass: Int
    var gold: Int; var silver: Int; var copper: Int
    var level: Int; var currentXP: Int
    var damageResponsesData: Data; var resourcesData: Data
    var conditionImmunitiesData: Data; var altFormsData: Data
    var strength: Int; var baseSpeed: Int
    var flySpeed: Int; var swimSpeed: Int; var climbSpeed: Int; var burrowSpeed: Int
    var inventoryData: Data
    var passivePerception: Int; var passiveInsight: Int; var passiveInvestigation: Int
    var darkvisionRange: Int; var sizeCategory: String; var tempHP: Int

    init(_ m: PlayerCharacter) {
        id = m.id; campaignID = m.campaignID; name = m.name; playerName = m.playerName
        combatSymbol = m.combatSymbol; currentHP = m.currentHP; maxHP = m.maxHP; armorClass = m.armorClass
        gold = m.gold; silver = m.silver; copper = m.copper
        level = m.level; currentXP = m.currentXP
        damageResponsesData = m.damageResponsesData; resourcesData = m.resourcesData
        conditionImmunitiesData = m.conditionImmunitiesData; altFormsData = m.altFormsData
        strength = m.strength; baseSpeed = m.baseSpeed
        flySpeed = m.flySpeed; swimSpeed = m.swimSpeed; climbSpeed = m.climbSpeed; burrowSpeed = m.burrowSpeed
        inventoryData = m.inventoryData
        passivePerception = m.passivePerception; passiveInsight = m.passiveInsight
        passiveInvestigation = m.passiveInvestigation; darkvisionRange = m.darkvisionRange
        sizeCategory = m.sizeCategory; tempHP = m.tempHP
    }
}

struct NPCTemplateDTO: Codable {
    var id: UUID; var campaignID: UUID; var name: String; var maxHP: Int; var hpFormula: String
    var initiative: Int; var armorClass: Int
    var damageResponsesData: Data; var conditionImmunitiesData: Data; var saveProficienciesData: Data
    var speed: Int; var flySpeed: Int; var swimSpeed: Int; var climbSpeed: Int; var burrowSpeed: Int; var canHover: Bool
    var strength: Int; var dexterity: Int; var constitution: Int
    var intelligence: Int; var wisdom: Int; var charisma: Int

    init(_ m: NPCTemplate) {
        id = m.id; campaignID = m.campaignID; name = m.name; maxHP = m.maxHP; hpFormula = m.hpFormula
        initiative = m.initiative; armorClass = m.armorClass
        damageResponsesData = m.damageResponsesData; conditionImmunitiesData = m.conditionImmunitiesData
        saveProficienciesData = m.saveProficienciesData
        speed = m.speed; flySpeed = m.flySpeed; swimSpeed = m.swimSpeed
        climbSpeed = m.climbSpeed; burrowSpeed = m.burrowSpeed; canHover = m.canHover
        strength = m.strength; dexterity = m.dexterity; constitution = m.constitution
        intelligence = m.intelligence; wisdom = m.wisdom; charisma = m.charisma
    }
}

struct MonsterTemplateDTO: Codable {
    var id: UUID; var campaignID: UUID; var isGlobal: Bool; var name: String
    var maxHP: Int; var hpFormula: String; var initiative: Int; var armorClass: Int
    var damageResponsesData: Data; var saveProficienciesData: Data; var conditionImmunitiesData: Data
    var strength: Int; var dexterity: Int; var constitution: Int
    var intelligence: Int; var wisdom: Int; var charisma: Int
    var challengeRatingValue: String
    var speed: Int; var flySpeed: Int; var swimSpeed: Int; var climbSpeed: Int; var burrowSpeed: Int; var canHover: Bool

    init(_ m: MonsterTemplate) {
        id = m.id; campaignID = m.campaignID; isGlobal = m.isGlobal; name = m.name
        maxHP = m.maxHP; hpFormula = m.hpFormula; initiative = m.initiative; armorClass = m.armorClass
        damageResponsesData = m.damageResponsesData; saveProficienciesData = m.saveProficienciesData
        conditionImmunitiesData = m.conditionImmunitiesData
        strength = m.strength; dexterity = m.dexterity; constitution = m.constitution
        intelligence = m.intelligence; wisdom = m.wisdom; charisma = m.charisma
        challengeRatingValue = m.challengeRatingValue
        speed = m.speed; flySpeed = m.flySpeed; swimSpeed = m.swimSpeed
        climbSpeed = m.climbSpeed; burrowSpeed = m.burrowSpeed; canHover = m.canHover
    }
}

struct EncounterFolderDTO: Codable {
    var id: UUID; var campaignID: UUID; var name: String; var sortOrder: Int

    init(_ m: EncounterFolder) {
        id = m.id; campaignID = m.campaignID; name = m.name; sortOrder = m.sortOrder
    }
}

struct SavedEncounterDTO: Codable {
    var id: UUID; var campaignID: UUID; var name: String; var folderID: UUID?
    var pcEntries: [EncounterPCEntry]
    var monsterEntries: [EncounterMonsterEntry]
    var npcEntries: [EncounterNPCEntry]
    var mapImageData: Data?

    init(_ m: SavedEncounter) {
        id = m.id; campaignID = m.campaignID; name = m.name; folderID = m.folderID
        pcEntries = m.pcEntries; monsterEntries = m.monsterEntries; npcEntries = m.npcEntries
        mapImageData = m.mapImageData
    }
}

struct CountryDTO: Codable {
    var id: UUID; var campaignID: UUID; var name: String; var sortOrder: Int
    var mapImageData: Data? = nil

    init(_ m: Country) {
        id = m.id; campaignID = m.campaignID; name = m.name; sortOrder = m.sortOrder
        mapImageData = m.mapImageData
    }
}

struct CityDTO: Codable {
    var id: UUID; var campaignID: UUID; var countryID: UUID; var name: String
    var mapImageData: Data?; var symbolImageData: Data? = nil; var cityDescription: String = ""

    init(_ m: City) {
        id = m.id; campaignID = m.campaignID; countryID = m.countryID; name = m.name
        mapImageData = m.mapImageData; symbolImageData = m.symbolImageData; cityDescription = m.cityDescription
    }
}

struct StoryPinDTO: Codable {
    var id: UUID; var cityID: UUID; var storyID: UUID; var xPosition: Double; var yPosition: Double

    init(_ m: StoryPin) {
        id = m.id; cityID = m.cityID; storyID = m.storyID
        xPosition = m.xPosition; yPosition = m.yPosition
    }
}

struct ShopPinDTO: Codable {
    var id: UUID; var cityID: UUID; var shopID: UUID; var xPosition: Double; var yPosition: Double

    init(_ m: ShopPin) {
        id = m.id; cityID = m.cityID; shopID = m.shopID
        xPosition = m.xPosition; yPosition = m.yPosition
    }
}

struct StoryDTO: Codable {
    var id: UUID; var campaignID: UUID; var name: String; var level: Int; var storyDescription: String
    var isCompleted: Bool; var isFailed: Bool; var isMainQuest: Bool; var rewardXP: Int; var xpAwarded: Bool
    var npcEntries: [StoryNPCEntry]
    var prerequisiteStoryIDs: [UUID]
    var locationCityID: UUID?
    var linkedEncounters: [StoryEncounterEntry]
    var linkedItems: [StoryItemEntry] = []

    init(_ m: Story) {
        id = m.id; campaignID = m.campaignID; name = m.name; level = m.level
        storyDescription = m.storyDescription; isCompleted = m.isCompleted; isFailed = m.isFailed
        isMainQuest = m.isMainQuest; rewardXP = m.rewardXP; xpAwarded = m.xpAwarded
        npcEntries = m.npcEntries; prerequisiteStoryIDs = m.prerequisiteStoryIDs
        locationCityID = m.locationCityID; linkedEncounters = m.linkedEncounters
        linkedItems = m.linkedItems
    }
}

struct ShopDTO: Codable {
    var id: UUID; var campaignID: UUID; var cityID: UUID; var name: String
    var shopTypeRaw: String; var qualityRaw: String; var questTypeRaw: String
    var shopDescription: String; var ownerName: String; var ownerNotes: String
    var startingGold: Double; var totalEarned: Double
    var storyID: UUID?; var ownerNPCID: UUID?
    var sortOrder: Int; var linkedStoryName: String
    var inventoryJSON: Data

    init(_ m: Shop) {
        id = m.id; campaignID = m.campaignID; cityID = m.cityID; name = m.name
        shopTypeRaw = m.shopTypeRaw; qualityRaw = m.qualityRaw; questTypeRaw = m.questTypeRaw
        shopDescription = m.shopDescription; ownerName = m.ownerName; ownerNotes = m.ownerNotes
        startingGold = m.startingGold; totalEarned = m.totalEarned
        storyID = m.storyID; ownerNPCID = m.ownerNPCID
        sortOrder = m.sortOrder; linkedStoryName = m.linkedStoryName
        inventoryJSON = (try? JSONEncoder().encode(m.inventory)) ?? Data()
    }
}

struct CustomCatalogItemDTO: Codable {
    var id: UUID; var campaignID: UUID; var name: String; var itemTypeRaw: String
    var category: String; var cost: String; var desc: String; var weight: String
    var rarityRaw: String; var attunement: Bool; var acString: String; var damageDice: String
    var spellLevel: String; var school: String; var castingTime: String; var spellRange: String
    var components: String; var duration: String; var concentration: Bool; var ritual: Bool

    init(_ m: CustomCatalogItem) {
        id = m.id; campaignID = m.campaignID; name = m.name; itemTypeRaw = m.itemTypeRaw
        category = m.category; cost = m.cost; desc = m.desc; weight = m.weight
        rarityRaw = m.rarityRaw; attunement = m.attunement; acString = m.acString; damageDice = m.damageDice
        spellLevel = m.spellLevel; school = m.school; castingTime = m.castingTime; spellRange = m.spellRange
        components = m.components; duration = m.duration; concentration = m.concentration; ritual = m.ritual
    }
}

struct PCWishlistItemDTO: Codable {
    var id: UUID; var pcID: UUID; var campaignID: UUID
    var slug: String; var name: String; var itemTypeRaw: String
    var priorityRaw: Int; var notes: String; var acquired: Bool; var addedAt: Date

    init(_ m: PCWishlistItem) {
        id = m.id; pcID = m.pcID; campaignID = m.campaignID
        slug = m.slug; name = m.name; itemTypeRaw = m.itemTypeRaw
        priorityRaw = m.priorityRaw; notes = m.notes; acquired = m.acquired; addedAt = m.addedAt
    }
}

struct WorldMapRecordDTO: Codable {
    var id: UUID; var campaignID: UUID; var imageData: Data?

    init(_ m: WorldMapRecord) {
        id = m.id; campaignID = m.campaignID; imageData = m.imageData
    }
}

struct GalleryFolderDTO: Codable {
    var id: UUID; var campaignID: UUID; var name: String; var sortOrder: Int; var isBuiltIn: Bool

    init(_ m: GalleryFolder) {
        id = m.id; campaignID = m.campaignID; name = m.name; sortOrder = m.sortOrder; isBuiltIn = m.isBuiltIn
    }
}

struct GalleryImageDTO: Codable {
    var id: UUID; var campaignID: UUID; var folderID: UUID; var title: String
    var imageData: Data; var sortOrder: Int; var createdAt: Date

    init(_ m: GalleryImage) {
        id = m.id; campaignID = m.campaignID; folderID = m.folderID; title = m.title
        imageData = m.imageData; sortOrder = m.sortOrder; createdAt = m.createdAt
    }
}

// MARK: - Export

func exportCampaignBundle(
    campaign: Campaign,
    players: [PlayerCharacter],
    npcs: [NPCTemplate],
    monsters: [MonsterTemplate],
    folders: [EncounterFolder],
    encounters: [SavedEncounter],
    countries: [Country],
    cities: [City],
    storyPins: [StoryPin],
    shopPins: [ShopPin],
    stories: [Story],
    shops: [Shop],
    customCatalogItems: [CustomCatalogItem],
    wishlistItems: [PCWishlistItem],
    worldMap: WorldMapRecord?,
    galleryFolders: [GalleryFolder] = [],
    galleryImages: [GalleryImage] = []
) throws -> Data {
    let bundle = CampaignBundle(
        campaign: CampaignDTO(campaign),
        players: players.map(PlayerCharacterDTO.init),
        npcs: npcs.map(NPCTemplateDTO.init),
        monsters: monsters.map(MonsterTemplateDTO.init),
        encounterFolders: folders.map(EncounterFolderDTO.init),
        encounters: encounters.map(SavedEncounterDTO.init),
        countries: countries.map(CountryDTO.init),
        cities: cities.map(CityDTO.init),
        storyPins: storyPins.map(StoryPinDTO.init),
        shopPins: shopPins.map(ShopPinDTO.init),
        stories: stories.map(StoryDTO.init),
        shops: shops.map(ShopDTO.init),
        customCatalogItems: customCatalogItems.map(CustomCatalogItemDTO.init),
        wishlistItems: wishlistItems.map(PCWishlistItemDTO.init),
        worldMap: worldMap.map(WorldMapRecordDTO.init),
        galleryFolders: galleryFolders.map(GalleryFolderDTO.init),
        galleryImages: galleryImages.map(GalleryImageDTO.init)
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(bundle)
}

// MARK: - Import

@discardableResult
func importCampaignBundle(from data: Data, into context: ModelContext) throws -> Campaign {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let bundle = try decoder.decode(CampaignBundle.self, from: data)

    var idMap: [UUID: UUID] = [:]
    func remap(_ old: UUID) -> UUID {
        if let existing = idMap[old] { return existing }
        let n = UUID(); idMap[old] = n; return n
    }
    func remapSlug(_ slug: String) -> String {
        guard slug.hasPrefix("custom-"),
              let oldUUID = UUID(uuidString: String(slug.dropFirst(7))),
              let newUUID = idMap[oldUUID]
        else { return slug }
        return "custom-\(newUUID.uuidString)"
    }

    for dto in bundle.players            { _ = remap(dto.id) }
    for dto in bundle.npcs               { _ = remap(dto.id) }
    for dto in bundle.monsters           { _ = remap(dto.id) }
    for dto in bundle.encounterFolders   { _ = remap(dto.id) }
    for dto in bundle.encounters         { _ = remap(dto.id) }
    for dto in bundle.countries          { _ = remap(dto.id) }
    for dto in bundle.cities             { _ = remap(dto.id) }
    for dto in bundle.storyPins          { _ = remap(dto.id) }
    for dto in bundle.shopPins           { _ = remap(dto.id) }
    for dto in bundle.stories            { _ = remap(dto.id) }
    for dto in bundle.shops              { _ = remap(dto.id) }
    for dto in bundle.customCatalogItems { _ = remap(dto.id) }
    for dto in bundle.wishlistItems      { _ = remap(dto.id) }
    for dto in bundle.galleryFolders     { _ = remap(dto.id) }
    for dto in bundle.galleryImages      { _ = remap(dto.id) }

    let newCampaignID = remap(bundle.campaign.id)

    let campaign = Campaign(name: bundle.campaign.name)
    campaign.id = newCampaignID
    campaign.trackXP = bundle.campaign.trackXP
    campaign.defaultHPMode = bundle.campaign.defaultHPMode
    context.insert(campaign)

    for dto in bundle.players {
        let pc = PlayerCharacter(name: dto.name, playerName: dto.playerName, maxHP: dto.maxHP, armorClass: dto.armorClass, campaignID: newCampaignID)
        pc.id = remap(dto.id)
        pc.combatSymbol = dto.combatSymbol; pc.currentHP = dto.currentHP
        pc.gold = dto.gold; pc.silver = dto.silver; pc.copper = dto.copper
        pc.level = dto.level; pc.currentXP = dto.currentXP
        pc.damageResponsesData = dto.damageResponsesData; pc.resourcesData = dto.resourcesData
        pc.conditionImmunitiesData = dto.conditionImmunitiesData; pc.altFormsData = dto.altFormsData
        pc.strength = dto.strength; pc.baseSpeed = dto.baseSpeed
        pc.flySpeed = dto.flySpeed; pc.swimSpeed = dto.swimSpeed
        pc.climbSpeed = dto.climbSpeed; pc.burrowSpeed = dto.burrowSpeed
        pc.inventoryData = dto.inventoryData
        pc.passivePerception = dto.passivePerception; pc.passiveInsight = dto.passiveInsight
        pc.passiveInvestigation = dto.passiveInvestigation; pc.darkvisionRange = dto.darkvisionRange
        pc.sizeCategory = dto.sizeCategory; pc.tempHP = dto.tempHP
        context.insert(pc)
    }

    for dto in bundle.npcs {
        let npc = NPCTemplate(name: dto.name, maxHP: dto.maxHP, hpFormula: dto.hpFormula, initiative: dto.initiative, armorClass: dto.armorClass, campaignID: newCampaignID)
        npc.id = remap(dto.id)
        npc.damageResponsesData = dto.damageResponsesData
        npc.conditionImmunitiesData = dto.conditionImmunitiesData
        npc.saveProficienciesData = dto.saveProficienciesData
        npc.speed = dto.speed; npc.flySpeed = dto.flySpeed; npc.swimSpeed = dto.swimSpeed
        npc.climbSpeed = dto.climbSpeed; npc.burrowSpeed = dto.burrowSpeed; npc.canHover = dto.canHover
        npc.strength = dto.strength; npc.dexterity = dto.dexterity; npc.constitution = dto.constitution
        npc.intelligence = dto.intelligence; npc.wisdom = dto.wisdom; npc.charisma = dto.charisma
        context.insert(npc)
    }

    for dto in bundle.monsters {
        let m = MonsterTemplate(name: dto.name, maxHP: dto.maxHP, hpFormula: dto.hpFormula, initiative: dto.initiative, armorClass: dto.armorClass, campaignID: newCampaignID, isGlobal: false)
        m.id = remap(dto.id)
        m.damageResponsesData = dto.damageResponsesData
        m.saveProficienciesData = dto.saveProficienciesData
        m.conditionImmunitiesData = dto.conditionImmunitiesData
        m.strength = dto.strength; m.dexterity = dto.dexterity; m.constitution = dto.constitution
        m.intelligence = dto.intelligence; m.wisdom = dto.wisdom; m.charisma = dto.charisma
        m.challengeRatingValue = dto.challengeRatingValue
        m.speed = dto.speed; m.flySpeed = dto.flySpeed; m.swimSpeed = dto.swimSpeed
        m.climbSpeed = dto.climbSpeed; m.burrowSpeed = dto.burrowSpeed; m.canHover = dto.canHover
        context.insert(m)
    }

    for dto in bundle.encounterFolders {
        let folder = EncounterFolder(name: dto.name, campaignID: newCampaignID, sortOrder: dto.sortOrder)
        folder.id = remap(dto.id)
        context.insert(folder)
    }

    for dto in bundle.encounters {
        let enc = SavedEncounter(name: dto.name, campaignID: newCampaignID)
        enc.id = remap(dto.id)
        enc.folderID = dto.folderID.map { remap($0) }
        enc.pcEntries = dto.pcEntries.map { EncounterPCEntry(id: $0.id, pcID: remap($0.pcID), pcName: $0.pcName) }
        enc.monsterEntries = dto.monsterEntries.map { EncounterMonsterEntry(id: $0.id, templateID: remap($0.templateID), templateName: $0.templateName, count: $0.count) }
        enc.npcEntries = dto.npcEntries.map { EncounterNPCEntry(id: $0.id, npcID: remap($0.npcID), npcName: $0.npcName) }
        enc.mapImageData = dto.mapImageData
        context.insert(enc)
    }

    for dto in bundle.countries {
        let country = Country(name: dto.name, campaignID: newCampaignID, sortOrder: dto.sortOrder)
        country.id = remap(dto.id)
        country.mapImageData = dto.mapImageData
        context.insert(country)
    }

    for dto in bundle.cities {
        let city = City(name: dto.name, campaignID: newCampaignID, countryID: remap(dto.countryID))
        city.id = remap(dto.id)
        city.mapImageData = dto.mapImageData
        city.symbolImageData = dto.symbolImageData
        city.cityDescription = dto.cityDescription
        context.insert(city)
    }

    for dto in bundle.customCatalogItems {
        let item = CustomCatalogItem(campaignID: newCampaignID, name: dto.name, itemType: CatalogItemType(rawValue: dto.itemTypeRaw) ?? .magicItem)
        item.id = remap(dto.id)
        item.category = dto.category; item.cost = dto.cost; item.desc = dto.desc; item.weight = dto.weight
        item.rarityRaw = dto.rarityRaw; item.attunement = dto.attunement; item.acString = dto.acString
        item.damageDice = dto.damageDice; item.spellLevel = dto.spellLevel; item.school = dto.school
        item.castingTime = dto.castingTime; item.spellRange = dto.spellRange; item.components = dto.components
        item.duration = dto.duration; item.concentration = dto.concentration; item.ritual = dto.ritual
        context.insert(item)
    }

    for dto in bundle.stories {
        let story = Story(name: dto.name, campaignID: newCampaignID)
        story.id = remap(dto.id)
        story.level = dto.level; story.storyDescription = dto.storyDescription
        story.isCompleted = dto.isCompleted; story.isFailed = dto.isFailed
        story.isMainQuest = dto.isMainQuest; story.rewardXP = dto.rewardXP; story.xpAwarded = dto.xpAwarded
        story.npcEntries = dto.npcEntries.map { StoryNPCEntry(id: $0.id, npcID: remap($0.npcID), npcName: $0.npcName) }
        story.prerequisiteStoryIDs = dto.prerequisiteStoryIDs.map { remap($0) }
        story.locationCityID = dto.locationCityID.map { remap($0) }
        story.linkedEncounters = dto.linkedEncounters.map { StoryEncounterEntry(id: $0.id, encounterID: remap($0.encounterID), encounterName: $0.encounterName, isCompleted: $0.isCompleted) }
        story.linkedItems = dto.linkedItems.map { StoryItemEntry(slug: remapSlug($0.slug), name: $0.name, itemTypeRaw: $0.itemTypeRaw) }
        context.insert(story)
    }

    for dto in bundle.shops {
        let shop = Shop(name: dto.name, campaignID: newCampaignID, cityID: remap(dto.cityID), shopType: ShopType(rawValue: dto.shopTypeRaw) ?? .weapons)
        shop.id = remap(dto.id)
        shop.qualityRaw = dto.qualityRaw
        shop.questTypeRaw = dto.questTypeRaw
        shop.shopDescription = dto.shopDescription; shop.ownerName = dto.ownerName; shop.ownerNotes = dto.ownerNotes
        shop.startingGold = dto.startingGold; shop.totalEarned = dto.totalEarned
        shop.storyID = dto.storyID.map { remap($0) }
        shop.ownerNPCID = dto.ownerNPCID.map { remap($0) }
        shop.sortOrder = dto.sortOrder
        shop.linkedStoryName = dto.linkedStoryName
        if let entries = try? JSONDecoder().decode([ShopInventoryEntry].self, from: dto.inventoryJSON) {
            let remapped = entries.map { e -> ShopInventoryEntry in
                var copy = e
                copy.slug = remapSlug(e.slug)
                return copy
            }
            shop.setInventory(remapped)
        }
        context.insert(shop)
    }

    for dto in bundle.storyPins {
        let pin = StoryPin(cityID: remap(dto.cityID), storyID: remap(dto.storyID), x: dto.xPosition, y: dto.yPosition)
        pin.id = remap(dto.id)
        context.insert(pin)
    }

    for dto in bundle.shopPins {
        let pin = ShopPin(cityID: remap(dto.cityID), shopID: remap(dto.shopID), x: dto.xPosition, y: dto.yPosition)
        pin.id = remap(dto.id)
        context.insert(pin)
    }

    for dto in bundle.wishlistItems {
        let item = PCWishlistItem(pcID: remap(dto.pcID), campaignID: newCampaignID, item: CatalogItem(slug: remapSlug(dto.slug), name: dto.name, type: CatalogItemType(rawValue: dto.itemTypeRaw) ?? .magicItem, category: "", cost: "", desc: "", source: "", rarity: .unknown, attunement: false, concentration: false, ritual: false))
        item.id = remap(dto.id)
        item.priorityRaw = dto.priorityRaw; item.notes = dto.notes
        item.acquired = dto.acquired; item.addedAt = dto.addedAt
        context.insert(item)
    }

    if let wm = bundle.worldMap {
        let rec = WorldMapRecord(campaignID: newCampaignID)
        rec.id = remap(wm.id)
        rec.imageData = wm.imageData
        context.insert(rec)
    }

    for dto in bundle.galleryFolders {
        let folder = GalleryFolder(name: dto.name, campaignID: newCampaignID, sortOrder: dto.sortOrder, isBuiltIn: dto.isBuiltIn)
        folder.id = remap(dto.id)
        context.insert(folder)
    }

    for dto in bundle.galleryImages {
        let img = GalleryImage(folderID: remap(dto.folderID), campaignID: newCampaignID, imageData: dto.imageData, title: dto.title, sortOrder: dto.sortOrder)
        img.id = remap(dto.id)
        img.createdAt = dto.createdAt
        context.insert(img)
    }

    return campaign
}
