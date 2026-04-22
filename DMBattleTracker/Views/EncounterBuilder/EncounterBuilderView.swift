import SwiftUI
import SwiftData

enum HPMode: String, CaseIterable {
    case average = "Average"
    case rolled = "Roll"
    case manual = "Manual"
}

struct InitiativeEntry: Identifiable {
    var id: UUID = UUID()
    var displayName: String
    var isPC: Bool
    var isNPC: Bool = false
    var pcID: UUID?
    var templateID: UUID?
    var npcTemplateID: UUID?
    var monsterSuffix: String = ""
    var initiativeBonus: Int = 0
    var initiativeText: String = ""
    var hpFormula: String = ""
    var hpMode: HPMode = .average
    var rolledHP: Int = 0
    var manualHPText: String = ""
    var hasEnteredCombat: Bool = true
    var nickname: String = ""

    var parsedInitiative: Int {
        guard let roll = Int(initiativeText) else { return initiativeBonus }
        return roll + initiativeBonus
    }

    var averageHP: Int { hpAverageFromFormula(hpFormula) }

    var parsedHP: Int? {
        guard !hpFormula.isEmpty else { return nil }
        switch hpMode {
        case .average: return averageHP
        case .rolled: return rolledHP
        case .manual: return Int(manualHPText).map { max(1, $0) } ?? averageHP
        }
    }

    mutating func reroll() {
        rolledHP = hpRollFromFormula(hpFormula)
    }
}

enum EncounterGroupMode {
    case folders, byStory
}

struct EncounterBuilderView: View {
    let campaign: Campaign
    var combatEngine: CombatEngine
    var onCombatStart: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var encounters: [SavedEncounter]
    @Query private var folders: [EncounterFolder]
    @Query private var allPCs: [PlayerCharacter]
    @Query private var allTemplates: [MonsterTemplate]
    @Query private var allNPCs: [NPCTemplate]
    @Query private var allStories: [Story]
    @Query private var allCities: [City]
    @Query private var allCountries: [Country]

    @Bindable var sectionState: SectionState
    @State private var showAddSheet: Bool = false
    @State private var collapsedFolders: Set<UUID> = []
    @State private var expandedCountries: Set<UUID> = []
    @State private var expandedCities: Set<UUID> = []
    @State private var groupMode: EncounterGroupMode = .folders
    @State private var search = ""
    @State private var showDeleteEncounterConfirm = false
    @State private var folderToDelete: EncounterFolder? = nil

    init(campaign: Campaign, sectionState: SectionState, combatEngine: CombatEngine, onCombatStart: @escaping () -> Void) {
        self.campaign = campaign
        _sectionState = Bindable(sectionState)
        self.combatEngine = combatEngine
        self.onCombatStart = onCombatStart
        let cid = campaign.id
        _encounters = Query(
            filter: #Predicate<SavedEncounter> { $0.campaignID == cid },
            sort: [SortDescriptor(\SavedEncounter.name)]
        )
        _folders = Query(
            filter: #Predicate<EncounterFolder> { $0.campaignID == cid },
            sort: [SortDescriptor(\EncounterFolder.sortOrder), SortDescriptor(\EncounterFolder.name)]
        )
        _allPCs = Query(
            filter: #Predicate<PlayerCharacter> { $0.campaignID == cid },
            sort: [SortDescriptor(\PlayerCharacter.name)]
        )
        _allTemplates = Query(
            filter: #Predicate<MonsterTemplate> { t in
                t.isGlobal || t.campaignID == cid
            },
            sort: [SortDescriptor(\MonsterTemplate.name)]
        )
        _allNPCs = Query(
            filter: #Predicate<NPCTemplate> { $0.campaignID == cid },
            sort: [SortDescriptor(\NPCTemplate.name)]
        )
        _allStories = Query(
            filter: #Predicate<Story> { $0.campaignID == cid },
            sort: [SortDescriptor(\Story.name)]
        )
        _allCities = Query(
            filter: #Predicate<City> { $0.campaignID == cid },
            sort: [SortDescriptor(\City.name)]
        )
        _allCountries = Query(
            filter: #Predicate<Country> { $0.campaignID == cid },
            sort: [SortDescriptor(\Country.sortOrder), SortDescriptor(\Country.name)]
        )
    }

    var filteredEncounters: [SavedEncounter] {
        search.isEmpty ? encounters : encounters.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.caption)
                    TextField("Search…", text: $search).textFieldStyle(.plain).font(.callout)
                    if !search.isEmpty {
                        Button { search = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    Divider().frame(height: 14)
                    Button {
                        groupMode = groupMode == .folders ? .byStory : .folders
                    } label: {
                        Image(systemName: groupMode == .byStory ? "globe.americas.fill" : "folder.fill")
                            .font(.caption)
                            .foregroundStyle(groupMode == .byStory ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(groupMode == .byStory ? "Switch to folders view" : "Group by story & location")
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                Divider()
            List(selection: $sectionState.selectedEncounter) {
                if groupMode == .folders {
                    let rootEncounters = filteredEncounters.filter { $0.folderID == nil }
                    if !rootEncounters.isEmpty {
                        Section {
                            ForEach(rootEncounters) { encounter in
                                encounterRow(encounter).tag(encounter)
                            }
                        }
                    }
                    ForEach(folders) { folder in
                        let isCollapsed = collapsedFolders.contains(folder.id)
                        Section {
                            if !isCollapsed {
                                ForEach(filteredEncounters.filter { $0.folderID == folder.id }) { encounter in
                                    encounterRow(encounter).tag(encounter)
                                }
                            }
                        } header: {
                            FolderSectionHeader(
                                folder: folder,
                                isCollapsed: isCollapsed,
                                onToggle: {
                                    if collapsedFolders.contains(folder.id) { collapsedFolders.remove(folder.id) }
                                    else { collapsedFolders.insert(folder.id) }
                                },
                                onDelete: { folderToDelete = folder }
                            )
                        }
                    }
                } else {
                    byStorysections
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddSheet = true } label: {
                        Label("New Encounter", systemImage: "plus")
                    }
                }
                ToolbarItem {
                    Button { addFolder() } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                }
                ToolbarItem {
                    Button { showDeleteEncounterConfirm = true } label: {
                        Label("Delete Encounter", systemImage: "trash")
                    }
                    .disabled(sectionState.selectedEncounter == nil)
                }
            }
            }
            .frame(minWidth: 230, maxWidth: 290)

            Divider()

            Group {
                if let encounter = sectionState.selectedEncounter {
                    EncounterDetailView(
                        campaign: campaign,
                        encounter: encounter,
                        folders: folders,
                        allPCs: allPCs,
                        allTemplates: allTemplates,
                        allNPCs: allNPCs,
                        combatEngine: combatEngine,
                        onCombatStart: onCombatStart
                    )
                } else {
                    ContentUnavailableView(
                        "No Encounter Selected",
                        systemImage: "checklist",
                        description: Text("Create a new encounter or select one from the list.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Encounter Builder")
        .sheet(isPresented: $showAddSheet) {
            AddEncounterSheet(campaignID: campaign.id)
        }
        .alert("Delete Encounter?", isPresented: $showDeleteEncounterConfirm) {
            Button("Delete", role: .destructive) {
                guard let e = sectionState.selectedEncounter else { return }
                modelContext.delete(e)
                sectionState.selectedEncounter = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let e = sectionState.selectedEncounter { Text("Delete '\(e.name)'? This cannot be undone.") }
        }
        .alert("Delete Folder?", isPresented: Binding(get: { folderToDelete != nil }, set: { if !$0 { folderToDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let f = folderToDelete { deleteFolder(f) }
                folderToDelete = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let f = folderToDelete { Text("Delete folder '\(f.name)'? Encounters inside will be moved to the root.") }
        }
    }

    @ViewBuilder
    private func encounterRow(_ encounter: SavedEncounter) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(encounter.name).font(.headline)
            Text("\(encounter.pcEntries.count) PCs · \(encounter.monsterEntries.reduce(0) { $0 + $1.count }) Enemies\(encounter.npcEntries.isEmpty ? "" : " · \(encounter.npcEntries.count) NPCs")")
                .font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                let xp = encounterXP(encounter)
                if xp > 0 {
                    Label("\(xp) XP", systemImage: "sparkles")
                        .font(.caption).foregroundStyle(.orange)
                }
                if encounter.mapImageData != nil {
                    Label("Map", systemImage: "map.fill")
                        .font(.caption).foregroundStyle(.teal)
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var byStorysections: some View {
        let linkedEncounterIDs: Set<UUID> = Set(allStories.flatMap { $0.linkedEncounters.map { $0.encounterID } })

        ForEach(allCountries) { country in
            let isExpanded = expandedCountries.contains(country.id)
            let countryCities = allCities.filter { $0.countryID == country.id }
            let countryStories = allStories.filter { s in
                guard let cid = s.locationCityID else { return false }
                return countryCities.contains(where: { $0.id == cid })
            }
            let countryEncounterCount = filteredEncounters.filter { enc in
                countryStories.contains(where: { $0.linkedEncounters.contains(where: { $0.encounterID == enc.id }) })
            }.count
            if countryEncounterCount > 0 || !isExpanded {
                Section {
                    if isExpanded {
                        ForEach(countryCities) { city in
                            let isCityExpanded = expandedCities.contains(city.id)
                            let cityStories = allStories.filter { $0.locationCityID == city.id }
                            let cityEncounterCount = filteredEncounters.filter { enc in
                                cityStories.contains(where: { $0.linkedEncounters.contains(where: { $0.encounterID == enc.id }) })
                            }.count
                            if cityEncounterCount > 0 {
                                EncounterCityHeader(cityName: city.name, count: cityEncounterCount, isExpanded: isCityExpanded) {
                                    if expandedCities.contains(city.id) { expandedCities.remove(city.id) }
                                    else { expandedCities.insert(city.id) }
                                }
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets())
                                if isCityExpanded {
                                    ForEach(cityStories) { story in
                                        let storyEncounters = filteredEncounters.filter { enc in
                                            story.linkedEncounters.contains(where: { $0.encounterID == enc.id })
                                        }
                                        if !storyEncounters.isEmpty {
                                            storyEncounterGroup(story: story, encounters: storyEncounters)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    EncounterCountryHeader(name: country.name, count: countryEncounterCount, isExpanded: isExpanded) {
                        if expandedCountries.contains(country.id) { expandedCountries.remove(country.id) }
                        else { expandedCountries.insert(country.id) }
                    }
                }
            }
        }

        let unlinked = filteredEncounters.filter { !linkedEncounterIDs.contains($0.id) }
        if !unlinked.isEmpty {
            Section("Unassigned") {
                ForEach(unlinked) { encounter in encounterRow(encounter).tag(encounter) }
            }
        }
    }

    @ViewBuilder
    private func storyEncounterGroup(story: Story, encounters: [SavedEncounter]) -> some View {
        HStack(spacing: 6) {
            Image(systemName: story.status.systemImage)
                .font(.caption2).foregroundStyle(story.status.color)
            Text(story.name)
                .font(.caption.bold()).foregroundStyle(.secondary)
            Spacer()
            Text("\(encounters.count)")
                .font(.caption2).foregroundStyle(.secondary)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Color.secondary.opacity(0.15)).clipShape(Capsule())
        }
        .padding(.leading, 32).padding(.vertical, 2)
        .listRowSeparator(.hidden)

        ForEach(encounters) { encounter in
            encounterRow(encounter)
                .tag(encounter)
                .padding(.leading, 16)
        }
    }

    private func addFolder() {
        let order = folders.count
        let folder = EncounterFolder(name: "New Folder", campaignID: campaign.id, sortOrder: order)
        modelContext.insert(folder)
    }

    private func deleteFolder(_ folder: EncounterFolder) {
        for encounter in encounters where encounter.folderID == folder.id {
            encounter.folderID = nil
        }
        modelContext.delete(folder)
    }

    private func encounterXP(_ encounter: SavedEncounter) -> Int {
        encounter.monsterEntries.reduce(0) { total, entry in
            guard let template = allTemplates.first(where: { $0.id == entry.templateID }) else { return total }
            return total + template.challengeRating.xp * entry.count
        }
    }
}

struct FolderSectionHeader: View {
    @Bindable var folder: EncounterFolder
    let isCollapsed: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onToggle) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
            }
            .buttonStyle(.plain)
            Image(systemName: "folder.fill")
                .foregroundStyle(.yellow)
                .font(.caption)
            TextField("Folder name", text: $folder.name)
                .font(.subheadline.bold())
                .textFieldStyle(.plain)
                .foregroundStyle(.primary)
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete folder (encounters move to root)")
        }
        .padding(.vertical, 2)
    }
}

struct EncounterCountryHeader: View {
    let name: String
    let count: Int
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onToggle) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2.bold()).foregroundStyle(.secondary).frame(width: 12)
            }
            .buttonStyle(.plain)
            Image(systemName: "globe").foregroundStyle(.blue).font(.caption)
            Text(name).font(.subheadline.bold())
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2)).clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}

struct EncounterCityHeader: View {
    let cityName: String
    let count: Int
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onToggle) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2).foregroundStyle(.secondary).frame(width: 10)
            }
            .buttonStyle(.plain)
            Image(systemName: "building.2.fill").foregroundStyle(.teal).font(.caption2)
            Text(cityName).font(.caption.bold())
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15)).clipShape(Capsule())
            }
        }
        .padding(.leading, 16).padding(.vertical, 3)
    }
}

struct EncounterDetailView: View {
    let campaign: Campaign
    @Bindable var encounter: SavedEncounter
    let folders: [EncounterFolder]
    let allPCs: [PlayerCharacter]
    let allTemplates: [MonsterTemplate]
    let allNPCs: [NPCTemplate]
    var combatEngine: CombatEngine
    var onCombatStart: () -> Void

    @Query private var allStories: [Story]

    @Environment(GalleryPresentationState.self) private var presentationState
    @Environment(\.openWindow) private var openWindow

    init(campaign: Campaign, encounter: SavedEncounter, folders: [EncounterFolder], allPCs: [PlayerCharacter], allTemplates: [MonsterTemplate], allNPCs: [NPCTemplate], combatEngine: CombatEngine, onCombatStart: @escaping () -> Void) {
        self.campaign = campaign
        _encounter = Bindable(encounter)
        self.folders = folders
        self.allPCs = allPCs
        self.allTemplates = allTemplates
        self.allNPCs = allNPCs
        self.combatEngine = combatEngine
        self.onCombatStart = onCombatStart
        let cid = campaign.id
        _allStories = Query(filter: #Predicate<Story> { $0.campaignID == cid })
    }

    var linkedStory: Story? {
        allStories.first { $0.linkedEncounters.contains(where: { $0.encounterID == encounter.id }) }
    }

    @State private var selectedFirstStrikerName: String = "None"
    @State private var showPCPicker: Bool = false
    @State private var showMonsterPicker: Bool = false
    @State private var showNPCPicker: Bool = false
    @State private var showInitiativeSheet: Bool = false
    @State private var showMapImporter: Bool = false
    @State private var pendingInitiativeEntries: [InitiativeEntry] = []

    var firstStrikerOptions: [String] {
        var options = ["None"]
        for entry in encounter.pcEntries { options.append(entry.pcName) }
        for entry in encounter.monsterEntries {
            for i in 0..<entry.count {
                options.append(entry.count > 1 ? "\(entry.templateName) \(i + 1)" : entry.templateName)
            }
        }
        for entry in encounter.npcEntries { options.append(entry.npcName) }
        return options
    }

    var totalCombatants: Int {
        encounter.pcEntries.count + encounter.monsterEntries.reduce(0) { $0 + $1.count } + encounter.npcEntries.count
    }

    var estimatedXP: Int {
        encounter.monsterEntries.reduce(0) { total, entry in
            guard let template = allTemplates.first(where: { $0.id == entry.templateID }) else { return total }
            return total + template.challengeRating.xp * entry.count
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Encounter Name", text: $encounter.name)
                            .font(.title2.bold())
                            .textFieldStyle(.plain)
                        if !folders.isEmpty {
                            Picker("", selection: Binding(
                                get: { encounter.folderID },
                                set: { encounter.folderID = $0 }
                            )) {
                                Text("No Folder").tag(UUID?.none)
                                ForEach(folders) { folder in
                                    Text(folder.name).tag(Optional(folder.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.caption)
                            .labelsHidden()
                        }
                    }
                    Spacer()
                    if estimatedXP > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.orange)
                            Text("\(estimatedXP) XP")
                                .font(.subheadline.bold())
                                .foregroundStyle(.orange)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    Button {
                        buildInitiativeEntries()
                        showInitiativeSheet = true
                    } label: {
                        Label("Start Combat", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.red)
                    .disabled(totalCombatants == 0)
                }

                if let story = linkedStory {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: story.status.systemImage)
                                    .foregroundStyle(story.status.color).font(.caption)
                                Text(story.name)
                                    .font(.subheadline.bold())
                                Text("·")
                                    .foregroundStyle(.tertiary)
                                Text(story.isMainQuest ? "Main Quest" : "Side Quest")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if !story.storyDescription.isEmpty {
                                Text(story.storyDescription)
                                    .font(.callout).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                    } label: {
                        Label("Linked Story", systemImage: "scroll.fill")
                            .font(.headline).foregroundStyle(.indigo)
                    }
                }

                GroupBox {
                    VStack(spacing: 0) {
                        ForEach(encounter.pcEntries) { entry in
                            HStack(spacing: 10) {
                                Image(systemName: "person.fill").foregroundStyle(.blue).frame(width: 20)
                                Text(entry.pcName)
                                    .font(.subheadline)
                                if let pc = allPCs.first(where: { $0.id == entry.pcID }) {
                                    Text("Lv \(pc.level)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    var entries = encounter.pcEntries
                                    entries.removeAll { $0.id == entry.id }
                                    encounter.pcEntries = entries
                                    if selectedFirstStrikerName == entry.pcName { selectedFirstStrikerName = "None" }
                                } label: {
                                    Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 9).padding(.horizontal, 12)
                            Divider()
                        }
                        Button { showPCPicker = true } label: {
                            Label("Add Player Character", systemImage: "plus.circle")
                        }
                        .padding(12)
                    }
                } label: {
                    Label("Player Characters (\(encounter.pcEntries.count))", systemImage: "person.2.fill")
                        .font(.headline)
                }
                .sheet(isPresented: $showPCPicker) {
                    PCPickerSheet(encounter: encounter, allPCs: allPCs)
                }

                GroupBox {
                    VStack(spacing: 0) {
                        ForEach(encounter.monsterEntries) { entry in
                            HStack(spacing: 10) {
                                Image(systemName: "flame.fill").foregroundStyle(.red).frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.templateName)
                                        .font(.subheadline)
                                    if let template = allTemplates.first(where: { $0.id == entry.templateID }) {
                                        HStack(spacing: 8) {
                                            Text("CR \(template.challengeRating.rawValue)")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                            Text("\(template.challengeRating.xp * entry.count) XP total")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                Spacer()
                                Text("×\(entry.count)").foregroundStyle(.secondary).font(.subheadline)
                                Stepper("", value: Binding(
                                    get: { encounter.monsterEntries.first(where: { $0.id == entry.id })?.count ?? 1 },
                                    set: { newCount in
                                        var entries = encounter.monsterEntries
                                        if let idx = entries.firstIndex(where: { $0.id == entry.id }) { entries[idx].count = max(1, newCount) }
                                        encounter.monsterEntries = entries
                                        selectedFirstStrikerName = "None"
                                    }
                                ), in: 1...20)
                                .labelsHidden().frame(width: 70)
                                Button {
                                    var entries = encounter.monsterEntries
                                    entries.removeAll { $0.id == entry.id }
                                    encounter.monsterEntries = entries
                                    selectedFirstStrikerName = "None"
                                } label: {
                                    Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 9).padding(.horizontal, 12)
                            Divider()
                        }
                        Button { showMonsterPicker = true } label: {
                            Label("Add Monster", systemImage: "plus.circle")
                        }
                        .padding(12)
                    }
                } label: {
                    Label("Enemies (\(encounter.monsterEntries.reduce(0) { $0 + $1.count }))", systemImage: "flame.fill")
                        .font(.headline)
                }
                .sheet(isPresented: $showMonsterPicker) {
                    MonsterPickerSheet(encounter: encounter, allTemplates: allTemplates)
                }

                GroupBox {
                    VStack(spacing: 0) {
                        ForEach(encounter.npcEntries) { entry in
                            HStack(spacing: 10) {
                                Image(systemName: "person.2.circle.fill").foregroundStyle(.green).frame(width: 20)
                                Text(entry.npcName)
                                    .font(.subheadline)
                                if let npc = allNPCs.first(where: { $0.id == entry.npcID }) {
                                    HStack(spacing: 8) {
                                        Text("HP \(npc.maxHP)")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Text("AC \(npc.armorClass)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button {
                                    var entries = encounter.npcEntries
                                    entries.removeAll { $0.id == entry.id }
                                    encounter.npcEntries = entries
                                    if selectedFirstStrikerName == entry.npcName { selectedFirstStrikerName = "None" }
                                } label: {
                                    Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 9).padding(.horizontal, 12)
                            Divider()
                        }
                        Button { showNPCPicker = true } label: {
                            Label("Add NPC Ally", systemImage: "plus.circle")
                        }
                        .padding(12)
                    }
                } label: {
                    Label("NPC Allies (\(encounter.npcEntries.count))", systemImage: "person.2.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                .sheet(isPresented: $showNPCPicker) {
                    NPCPickerSheet(encounter: encounter, allNPCs: allNPCs)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("This combatant acts immediately before normal initiative order in Round 1. Their regular Round 1 turn is then skipped, resuming normally from Round 2.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Picker("First Striker", selection: $selectedFirstStrikerName) {
                            ForEach(firstStrikerOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .labelsHidden().pickerStyle(.menu).disabled(totalCombatants == 0)
                    }
                    .padding(10)
                } label: {
                    Label("First Strike Mechanic", systemImage: "bolt.badge.clock.fill").font(.headline)
                }

                GroupBox {
                    VStack(spacing: 10) {
                        if let mapData = encounter.mapImageData, let nsImage = NSImage(data: mapData) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            HStack(spacing: 10) {
                                Button {
                                    presentationState.items = [GalleryPresentationItem(title: encounter.name, data: mapData)]
                                    presentationState.currentIndex = 0
                                    openWindow(id: "gallery-presentation")
                                } label: {
                                    Label("Present on Screen", systemImage: "display")
                                }
                                .buttonStyle(.borderedProminent).tint(.indigo)

                                Spacer()

                                Button {
                                    showMapImporter = true
                                } label: {
                                    Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                                }
                                .buttonStyle(.bordered)

                                Button(role: .destructive) {
                                    encounter.mapImageData = nil
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                            }
                        } else {
                            Button {
                                showMapImporter = true
                            } label: {
                                Label("Import Battle Map…", systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }
                    .padding(10)
                } label: {
                    Label("Battle Map", systemImage: "map.fill").font(.headline)
                }
                .fileImporter(
                    isPresented: $showMapImporter,
                    allowedContentTypes: [.image],
                    allowsMultipleSelection: false
                ) { result in
                    guard case .success(let urls) = result, let url = urls.first else { return }
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    if let data = try? Data(contentsOf: url),
                       let nsImage = NSImage(data: data),
                       let png = nsImage.encounterMapPngData {
                        encounter.mapImageData = png
                    }
                }

                Spacer()
            }
            .padding(20)
        }
        .sheet(isPresented: $showInitiativeSheet) {
            InitiativeRollSheet(entries: $pendingInitiativeEntries) {
                launchCombat()
            }
        }
    }

    func buildInitiativeEntries() {
        let defaultMode = HPMode(rawValue: campaign.defaultHPMode) ?? .average
        var entries: [InitiativeEntry] = []
        for entry in encounter.pcEntries {
            let pc = allPCs.first(where: { $0.id == entry.pcID })
            var e = InitiativeEntry(
                displayName: entry.pcName,
                isPC: true,
                pcID: entry.pcID,
                initiativeBonus: 0
            )
            e.nickname = pc?.combatSymbol ?? ""
            entries.append(e)
        }
        for entry in encounter.monsterEntries {
            let template = allTemplates.first(where: { $0.id == entry.templateID })
            let bonus = template?.initiative ?? 0
            let formula = template?.hpFormula ?? ""
            for i in 0..<entry.count {
                let suffix = entry.count > 1 ? "\(i + 1)" : ""
                let name = suffix.isEmpty ? entry.templateName : "\(entry.templateName) \(suffix)"
                var e = InitiativeEntry(
                    displayName: name,
                    isPC: false,
                    templateID: entry.templateID,
                    monsterSuffix: suffix,
                    initiativeBonus: bonus,
                    hpFormula: formula
                )
                e.hpMode = defaultMode
                e.rolledHP = formula.isEmpty ? 0 : hpRollFromFormula(formula)
                if campaign.autoRollInitiative {
                    e.initiativeText = "\(Int.random(in: 1...20))"
                }
                entries.append(e)
            }
        }
        for entry in encounter.npcEntries {
            let npc = allNPCs.first(where: { $0.id == entry.npcID })
            var e = InitiativeEntry(
                displayName: entry.npcName,
                isPC: false,
                npcTemplateID: entry.npcID,
                initiativeBonus: npc?.initiative ?? 0
            )
            e.isNPC = true
            if campaign.autoRollInitiative {
                e.initiativeText = "\(Int.random(in: 1...20))"
            }
            entries.append(e)
        }
        pendingInitiativeEntries = entries
    }

    func launchCombat() {
        var combatants: [Combatant] = []
        var firstStrikerID: UUID? = nil

        for entry in pendingInitiativeEntries {
            let initiative = entry.parsedInitiative
            let c: Combatant

            if entry.isPC, let pcID = entry.pcID, let pc = allPCs.first(where: { $0.id == pcID }) {
                c = Combatant.fromPC(pc, initiative: initiative)
            } else if entry.isNPC, let npcID = entry.npcTemplateID,
                      let npc = allNPCs.first(where: { $0.id == npcID }) {
                c = Combatant.fromNPCTemplate(npc, initiative: initiative)
            } else if !entry.isPC && !entry.isNPC, let templateID = entry.templateID,
                      let template = allTemplates.first(where: { $0.id == templateID }) {
                c = Combatant.fromTemplate(template, suffix: entry.monsterSuffix, initiative: initiative)
                if let hp = entry.parsedHP {
                    c.maxHP = hp
                    c.currentHP = hp
                }
            } else {
                c = Combatant(
                    name: entry.displayName,
                    currentHP: 10, maxHP: 10,
                    initiative: initiative, armorClass: 10,
                    damageResponsesDict: [:], isPC: entry.isPC
                )
            }

            c.nickname = entry.nickname
            c.hasEnteredCombat = entry.hasEnteredCombat
            if entry.displayName == selectedFirstStrikerName {
                firstStrikerID = c.id
            }
            combatants.append(c)
        }

        combatEngine.activeEncounterID = encounter.id
        combatEngine.startCombat(combatants: combatants, firstStrikerID: firstStrikerID)
        onCombatStart()
    }
}

struct InitiativeRollSheet: View {
    @Binding var entries: [InitiativeEntry]
    var onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var monstersWithFormula: [Int] {
        entries.indices.filter { !entries[$0].isPC && !entries[$0].isNPC && !entries[$0].hpFormula.isEmpty }
    }

    var enemyIndices: [Int] {
        entries.indices.filter { !entries[$0].isPC && !entries[$0].isNPC }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Set Initiative Order")
                    .font(.title2.bold())
                Text("Enter the raw d20 roll. Bonuses are added automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            HStack(spacing: 0) {
                Text("Combatant")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("d20 Roll")
                    .frame(width: 74, alignment: .center)
                Text("Bonus")
                    .frame(width: 52, alignment: .center)
                Text("Total")
                    .frame(width: 52, alignment: .center)
                Text("Active")
                    .frame(width: 60, alignment: .center)
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.04))

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach($entries) { $entry in
                        HStack(spacing: 0) {
                            HStack(spacing: 8) {
                                Image(systemName: entry.isPC ? "person.fill" : entry.isNPC ? "person.2.circle.fill" : "flame.fill")
                                    .foregroundStyle(entry.isPC ? Color.blue : entry.isNPC ? Color.green : (entry.hasEnteredCombat ? Color.red : Color.orange))
                                    .frame(width: 16)
                                Text(entry.displayName)
                                    .font(.subheadline.bold())
                                if !entry.hasEnteredCombat {
                                    Text("LATE")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundStyle(.orange)
                                        .clipShape(Capsule())
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            TextField("", text: $entry.initiativeText, prompt: Text("—"))
                                .multilineTextAlignment(.center)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 58)
                                .frame(width: 74, alignment: .center)

                            Group {
                                if entry.initiativeBonus != 0 {
                                    Text(entry.initiativeBonus > 0 ? "+\(entry.initiativeBonus)" : "\(entry.initiativeBonus)")
                                        .font(.caption.bold())
                                        .foregroundStyle(entry.initiativeBonus > 0 ? .green : .red)
                                } else {
                                    Text("—").foregroundStyle(.tertiary)
                                }
                            }
                            .font(.caption.bold())
                            .frame(width: 52, alignment: .center)

                            Group {
                                if !entry.initiativeText.isEmpty {
                                    Text("\(entry.parsedInitiative)")
                                        .font(.subheadline.bold().monospacedDigit())
                                        .foregroundStyle(.primary)
                                } else {
                                    Text("?").foregroundStyle(.tertiary)
                                }
                            }
                            .frame(width: 52, alignment: .center)

                            Toggle("", isOn: $entry.hasEnteredCombat)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .frame(width: 60, alignment: .center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)

                        Divider().padding(.leading, 24)
                    }

                    if !monstersWithFormula.isEmpty {
                        sectionHeader("Monster HP")
                        ForEach(monstersWithFormula, id: \.self) { idx in
                            HPModeRow(entry: $entries[idx])
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                            Divider().padding(.leading, 24)
                        }
                    }

                    if !enemyIndices.isEmpty {
                        sectionHeader("Enemy Nicknames — optional, shown during combat")
                        ForEach(enemyIndices, id: \.self) { idx in
                            NicknameEntryRow(entry: $entries[idx])
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                            Divider().padding(.leading, 24)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Begin Combat") {
                    onConfirm()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(minWidth: 580, minHeight: 480)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }
}

let whitePieces = ["♔", "♕", "♖", "♗", "♘", "♙"]
let blackPieces = ["♚", "♛", "♜", "♝", "♞", "♟"]
let allChessPieces = whitePieces + blackPieces

struct NicknameEntryRow: View {
    @Binding var entry: InitiativeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").foregroundStyle(.red).font(.caption)
                Text(entry.displayName).font(.subheadline.bold())
                if !entry.nickname.isEmpty {
                    Text(entry.nickname)
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(whitePieces, id: \.self) { piece in
                        ChessPieceButton(piece: piece, isSelected: entry.nickname == piece, isWhite: true) {
                            entry.nickname = entry.nickname == piece ? "" : piece
                        }
                    }
                    Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 1, height: 22)
                    ForEach(blackPieces, id: \.self) { piece in
                        ChessPieceButton(piece: piece, isSelected: entry.nickname == piece, isWhite: false) {
                            entry.nickname = entry.nickname == piece ? "" : piece
                        }
                    }
                    Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 1, height: 22)
                    TextField("Custom", text: Binding(
                        get: { allChessPieces.contains(entry.nickname) ? "" : entry.nickname },
                        set: { entry.nickname = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ChessPieceButton: View {
    let piece: String
    let isSelected: Bool
    let isWhite: Bool
    let action: () -> Void

    var bgColor: Color {
        isWhite ? Color(red: 0.90, green: 0.87, blue: 0.76) : Color(red: 0.10, green: 0.10, blue: 0.13)
    }
    var fgColor: Color { isWhite ? Color(red: 0.08, green: 0.06, blue: 0.04) : .white }

    var body: some View {
        Button(action: action) {
            Text(piece)
                .font(.title3)
                .foregroundStyle(fgColor)
                .frame(width: 36, height: 32)
                .background(isSelected ? bgColor : bgColor.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(bgColor.opacity(isSelected ? 0.9 : 0.12), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

struct HPModeRow: View {
    @Binding var entry: InitiativeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill").foregroundStyle(.red).frame(width: 16)
                Text(entry.displayName).font(.subheadline.bold())
                Text(entry.hpFormula)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                HPModeButton(
                    label: "Average · \(entry.averageHP)",
                    icon: "equal.circle.fill",
                    color: .blue,
                    selected: entry.hpMode == .average
                ) {
                    entry.hpMode = .average
                }

                HPModeButton(
                    label: "Roll · \(entry.rolledHP)",
                    icon: "dice.fill",
                    color: .orange,
                    selected: entry.hpMode == .rolled
                ) {
                    entry.reroll()
                    entry.hpMode = .rolled
                }

                if entry.hpMode == .rolled {
                    Button {
                        entry.reroll()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                HPModeButton(
                    label: "Manual",
                    icon: "pencil.circle.fill",
                    color: .purple,
                    selected: entry.hpMode == .manual
                ) {
                    if entry.manualHPText.isEmpty {
                        entry.manualHPText = "\(entry.averageHP)"
                    }
                    entry.hpMode = .manual
                }

                if entry.hpMode == .manual {
                    TextField("HP", text: $entry.manualHPText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 64)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct HPModeButton: View {
    let label: String
    let icon: String
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption.bold())
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(selected ? color : Color.secondary.opacity(0.3))
        .controlSize(.small)
    }
}

struct PCPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var encounter: SavedEncounter
    let allPCs: [PlayerCharacter]

    @State private var selected: Set<UUID> = []

    var availablePCs: [PlayerCharacter] {
        let existingIDs = Set(encounter.pcEntries.map { $0.pcID })
        return allPCs.filter { !existingIDs.contains($0.id) }
    }

    private var allSelected: Bool { availablePCs.allSatisfy { selected.contains($0.id) } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Player Characters").font(.headline)
                Spacer()
                Button(allSelected ? "Deselect All" : "Select All") {
                    if allSelected {
                        selected.removeAll()
                    } else {
                        availablePCs.forEach { selected.insert($0.id) }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(availablePCs.isEmpty)
                Button("Add \(selected.isEmpty ? "" : "(\(selected.count))")") {
                    var entries = encounter.pcEntries
                    for pc in allPCs where selected.contains(pc.id) {
                        entries.append(EncounterPCEntry(pcID: pc.id, pcName: pc.name))
                    }
                    encounter.pcEntries = entries
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            Divider()

            if availablePCs.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "All Characters Added",
                    systemImage: "checkmark.circle",
                    description: Text("All characters from the PC Library are already in this encounter.")
                )
                Spacer()
            } else {
                List(availablePCs) { pc in
                    let isSelected = selected.contains(pc.id)
                    Button {
                        if isSelected { selected.remove(pc.id) } else { selected.insert(pc.id) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? .blue : .secondary)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    if !pc.combatSymbol.isEmpty { Text(pc.combatSymbol).font(.subheadline) }
                                    Text(pc.name).font(.headline).foregroundStyle(.primary)
                                    Text("Lv \(pc.level)")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.15)).foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                }
                                Text("HP \(pc.maxHP) · AC \(pc.armorClass)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }

            Divider()
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered).keyboardShortcut(.cancelAction)
                Spacer()
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(minWidth: 360, minHeight: 360)
    }
}

struct MonsterPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var encounter: SavedEncounter
    let allTemplates: [MonsterTemplate]

    @State private var search = ""
    @State private var counts: [UUID: Int] = [:]

    var filtered: [MonsterTemplate] {
        search.isEmpty ? allTemplates : allTemplates.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    func count(for id: UUID) -> Int { counts[id] ?? 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Monsters").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.borderless)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            Divider()

            TextField("Search…", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16).padding(.vertical, 8)

            Divider()

            if allTemplates.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Monsters in Bestiary",
                    systemImage: "book.closed",
                    description: Text("Add monster templates in the Bestiary section first.")
                )
                Spacer()
            } else {
                List(filtered) { template in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name).font(.subheadline.bold()).foregroundStyle(.primary)
                            HStack(spacing: 8) {
                                Text("HP \(template.maxHP) · AC \(template.armorClass)")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("CR \(template.challengeRating.rawValue)")
                                    .font(.caption).foregroundStyle(.orange)
                                Text("\(template.challengeRating.xp) XP")
                                    .font(.caption).foregroundStyle(.purple)
                            }
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            Stepper("", value: Binding(
                                get: { count(for: template.id) },
                                set: { counts[template.id] = max(1, $0) }
                            ), in: 1...99)
                            .labelsHidden()
                            .frame(width: 72)
                            Text("×\(count(for: template.id))")
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 32)
                        }
                        Button {
                            let n = count(for: template.id)
                            var entries = encounter.monsterEntries
                            if let idx = entries.firstIndex(where: { $0.templateID == template.id }) {
                                entries[idx].count += n
                            } else {
                                entries.append(EncounterMonsterEntry(templateID: template.id, templateName: template.name, count: n))
                            }
                            encounter.monsterEntries = entries
                            counts[template.id] = 1
                        } label: {
                            Image(systemName: "plus.circle.fill").foregroundStyle(.red).font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }

            Divider()
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered).keyboardShortcut(.cancelAction)
                Spacer()
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(minWidth: 420, minHeight: 400)
    }
}

struct NPCPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var encounter: SavedEncounter
    let allNPCs: [NPCTemplate]

    @State private var selected: Set<UUID> = []

    var availableNPCs: [NPCTemplate] {
        let existingIDs = Set(encounter.npcEntries.map { $0.npcID })
        return allNPCs.filter { !existingIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add NPC Allies").font(.headline)
                Spacer()
                Button("Add \(selected.isEmpty ? "" : "(\(selected.count))")") {
                    var entries = encounter.npcEntries
                    for npc in allNPCs where selected.contains(npc.id) {
                        entries.append(EncounterNPCEntry(npcID: npc.id, npcName: npc.name))
                    }
                    encounter.npcEntries = entries
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            Divider()

            if allNPCs.isEmpty {
                Spacer()
                ContentUnavailableView("No NPCs Defined", systemImage: "person.2.circle",
                    description: Text("Add NPCs in the NPC Library section first."))
                Spacer()
            } else if availableNPCs.isEmpty {
                Spacer()
                ContentUnavailableView("All NPCs Added", systemImage: "checkmark.circle",
                    description: Text("All NPC allies are already in this encounter."))
                Spacer()
            } else {
                List(availableNPCs) { npc in
                    let isSelected = selected.contains(npc.id)
                    Button {
                        if isSelected { selected.remove(npc.id) } else { selected.insert(npc.id) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? .green : .secondary).font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(npc.name).font(.headline).foregroundStyle(.primary)
                                Text("HP \(npc.maxHP) · AC \(npc.armorClass)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }

            Divider()
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered).keyboardShortcut(.cancelAction)
                Spacer()
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(minWidth: 360, minHeight: 360)
    }
}

struct AddEncounterSheet: View {
    let campaignID: UUID
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.system(size: 32))
                    .foregroundStyle(Color(red: 0.95, green: 0.65, blue: 0.2))
                Text("New Encounter").font(.title2.bold())
            }
            .padding(.top, 24).padding(.bottom, 16)

            Divider()

            VStack(spacing: 16) {
                SheetFormRow(label: "Name") {
                    TextField("e.g. Goblin Ambush", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
            }
            .padding(.horizontal, 32).padding(.vertical, 24)

            Spacer(minLength: 0)
            Divider()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") {
                    let encounter = SavedEncounter(
                        name: name.isEmpty ? "New Encounter" : name,
                        campaignID: campaignID
                    )
                    modelContext.insert(encounter)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.95, green: 0.65, blue: 0.2))
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(width: 400, height: 240)
    }
}


// MARK: - NSImage extension

private extension NSImage {
    var encounterMapPngData: Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
