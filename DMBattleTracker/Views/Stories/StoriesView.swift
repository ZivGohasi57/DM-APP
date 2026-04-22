import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - StoriesView

struct StoriesView: View {
    let campaign: Campaign
    @Bindable var sectionState: SectionState
    @Environment(\.modelContext) private var modelContext
    @Query private var stories: [Story]
    @Query private var allNPCs: [NPCTemplate]
    @Query private var countries: [Country]
    @Query private var cities: [City]

    @State private var showAddSheet = false
    @State private var search = ""
    @State private var filterStatus: StoryStatus? = nil
    @State private var filterQuestType: QuestTypeFilter = .all
    @State private var expandedCountries: Set<UUID> = []
    @State private var expandedCities: Set<UUID> = []
    @State private var exportItem: StoryExportFile? = nil
    @State private var showDeleteConfirm = false

    init(campaign: Campaign, sectionState: SectionState) {
        self.campaign = campaign
        _sectionState = Bindable(sectionState)
        let cid = campaign.id
        _stories  = Query(filter: #Predicate<Story> { $0.campaignID == cid }, sort: [SortDescriptor(\Story.name)])
        _allNPCs  = Query(filter: #Predicate<NPCTemplate> { $0.campaignID == cid }, sort: [SortDescriptor(\NPCTemplate.name)])
        _countries = Query(filter: #Predicate<Country> { $0.campaignID == cid }, sort: [SortDescriptor(\Country.sortOrder), SortDescriptor(\Country.name)])
        _cities   = Query(filter: #Predicate<City> { $0.campaignID == cid }, sort: [SortDescriptor(\City.name)])
    }

    var filteredStories: [Story] {
        stories.filter { story in
            let matchesSearch = search.isEmpty || story.name.localizedCaseInsensitiveContains(search)
            let matchesStatus = filterStatus == nil || story.status == filterStatus
            let matchesType: Bool
            switch filterQuestType {
            case .all:  matchesType = true
            case .main: matchesType = story.isMainQuest
            case .side: matchesType = !story.isMainQuest
            }
            return matchesSearch && matchesStatus && matchesType
        }
    }

    private var mainQuests: [Story] { stories.filter { $0.isMainQuest } }
    private var mainCompleted: Int { mainQuests.filter { $0.status == .completed }.count }
    private var allCompleted: Int { stories.filter { $0.status == .completed }.count }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                if !stories.isEmpty {
                    QuestProgressHeader(
                        mainTotal: mainQuests.count,
                        mainCompleted: mainCompleted,
                        allTotal: stories.count,
                        allCompleted: allCompleted
                    )
                    Divider()

                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary).font(.caption)
                        TextField("Search…", text: $search)
                            .textFieldStyle(.plain).font(.callout)
                        if !search.isEmpty {
                            Button { search = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary).font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        Divider().frame(height: 14)
                        Menu {
                            Button("All Statuses") { filterStatus = nil }
                            Divider()
                            ForEach(StoryStatus.allCases) { s in
                                Button {
                                    filterStatus = (filterStatus == s) ? nil : s
                                } label: {
                                    Label(s.rawValue, systemImage: s.systemImage)
                                        .foregroundStyle(s.color)
                                }
                            }
                        } label: {
                            Image(systemName: filterStatus == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                                .foregroundStyle(filterStatus == nil ? Color.secondary : Color.accentColor)
                                .font(.caption)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        Menu {
                            Button("All Types") { filterQuestType = .all }
                            Button("Main Quest") { filterQuestType = .main }
                            Button("Side Quest") { filterQuestType = .side }
                        } label: {
                            Image(systemName: filterQuestType == .all ? "tray.full" : "tray.full.fill")
                                .foregroundStyle(filterQuestType == .all ? Color.secondary : Color.accentColor)
                                .font(.caption)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    Divider()
                }

                List(selection: $sectionState.selectedStory) {
                    storySections
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showAddSheet = true } label: {
                            Label("New Story", systemImage: "plus")
                        }
                    }
                    ToolbarItem {
                        Button {
                            exportItem = buildExportFile()
                        } label: {
                            Label("Export JSON", systemImage: "arrow.up.doc.fill")
                        }
                        .disabled(stories.isEmpty)
                        .help("Export all stories to JSON")
                    }
                    ToolbarItem {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(sectionState.selectedStory == nil)
                    }
                }
            }
            .frame(minWidth: 220, maxWidth: 270)

            Divider()

            Group {
                if let story = sectionState.selectedStory {
                    StoryDetailView(
                        story: story,
                        allNPCs: allNPCs,
                        allStories: stories,
                        campaign: campaign,
                        countries: countries,
                        cities: cities,
                        sectionState: sectionState
                    )
                } else {
                    ContentUnavailableView(
                        "No Story Selected",
                        systemImage: "scroll",
                        description: Text("Create a new story or select one from the list.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Stories")
        .sheet(isPresented: $showAddSheet) {
            AddStorySheet(campaignID: campaign.id)
        }
        .alert("Delete Story?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                guard let s = sectionState.selectedStory else { return }
                modelContext.delete(s)
                sectionState.selectedStory = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let s = sectionState.selectedStory { Text("Delete '\(s.name)'? This cannot be undone.") }
        }
        .fileExporter(
            isPresented: Binding(get: { exportItem != nil }, set: { if !$0 { exportItem = nil } }),
            document: exportItem,
            contentType: .json,
            defaultFilename: "\(campaign.name) — Stories"
        ) { _ in
            exportItem = nil
        }
    }

    private func buildExportFile() -> StoryExportFile {
        let cityMap = Dictionary(uniqueKeysWithValues: cities.map { ($0.id, $0.name) })
        let npcMap  = Dictionary(uniqueKeysWithValues: allNPCs.map { ($0.id, $0.name) })

        let dtos = stories.sorted { $0.name < $1.name }.map { story -> StoryExportDTO in
            StoryExportDTO(
                name: story.name,
                status: story.status.rawValue,
                type: story.isMainQuest ? "Main Quest" : "Side Quest",
                level: story.level,
                description: story.storyDescription,
                rewardXP: story.rewardXP,
                xpAwarded: story.xpAwarded,
                location: story.locationCityID.flatMap { cityMap[$0] },
                npcs: story.npcEntries.map { $0.npcName },
                linkedEncounters: story.linkedEncounters.map {
                    LinkedEncounterExport(name: $0.encounterName, completed: $0.isCompleted)
                },
                prerequisiteStoryNames: story.prerequisiteStoryIDs.compactMap { pid in
                    stories.first { $0.id == pid }?.name
                }
            )
        }

        let bundle = StoryExportBundle(
            campaignName: campaign.name,
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            totalStories: stories.count,
            stories: dtos
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = (try? encoder.encode(bundle)) ?? Data()
        return StoryExportFile(data: data)
    }

    @ViewBuilder
    private var storySections: some View {
        let displayed = filteredStories

        ForEach(countries) { country in
            let isCountryExpanded = expandedCountries.contains(country.id)
            let countryCities = cities.filter { $0.countryID == country.id }

            Section {
                if isCountryExpanded {
                    ForEach(countryCities) { city in
                        let cityStories = displayed.filter { $0.locationCityID == city.id }
                        if !cityStories.isEmpty || search.isEmpty {
                            let isCityExpanded = expandedCities.contains(city.id)
                            cityRow(city: city, stories: cityStories, isExpanded: isCityExpanded)
                        }
                    }
                }
            } header: {
                CountryStoryHeader(
                    country: country,
                    storyCount: displayed.filter { story in
                        countryCities.contains(where: { $0.id == story.locationCityID })
                    }.count,
                    isExpanded: isCountryExpanded,
                    onToggle: { toggleCountry(country.id) }
                )
            }
        }

        let unassigned = displayed.filter { s in
            s.locationCityID == nil || !cities.contains(where: { $0.id == s.locationCityID })
        }
        if !unassigned.isEmpty || (stories.filter { $0.locationCityID == nil }.count > 0 && search.isEmpty && filterStatus == nil && filterQuestType == .all) {
            Section("Unassigned") {
                let mainUnassigned = unassigned.filter { $0.isMainQuest }
                let sideUnassigned = unassigned.filter { !$0.isMainQuest }

                if !mainUnassigned.isEmpty {
                    questTypeLabel("Main Quests", color: .orange)
                    ForEach(mainUnassigned) { story in storyRow(story).tag(story) }
                }
                if !sideUnassigned.isEmpty {
                    questTypeLabel("Side Quests", color: .blue)
                    ForEach(sideUnassigned) { story in storyRow(story).tag(story) }
                }
            }
        }

        if displayed.isEmpty && !stories.isEmpty {
            Text("No matching stories")
                .foregroundStyle(.secondary).font(.callout)
        }
        if stories.isEmpty {
            Text("No stories yet")
                .foregroundStyle(.secondary).font(.callout)
        }
    }

    @ViewBuilder
    private func cityRow(city: City, stories cityStories: [Story], isExpanded: Bool) -> some View {
        CityStoryHeader(
            cityName: city.name,
            storyCount: cityStories.count,
            isExpanded: isExpanded,
            onToggle: { toggleCity(city.id) }
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

        if isExpanded {
            let mainStories = cityStories.filter { $0.isMainQuest }
            let sideStories = cityStories.filter { !$0.isMainQuest }

            if !mainStories.isEmpty {
                questTypeLabel("Main Quests", color: .orange)
                ForEach(mainStories) { story in storyRow(story).tag(story) }
            }
            if !sideStories.isEmpty {
                questTypeLabel("Side Quests", color: .blue)
                ForEach(sideStories) { story in storyRow(story).tag(story) }
            }
            if cityStories.isEmpty {
                Text("No stories pinned here")
                    .font(.caption).foregroundStyle(.tertiary)
                    .padding(.leading, 24).padding(.vertical, 4)
                    .listRowSeparator(.hidden)
            }
        }
    }

    @ViewBuilder
    private func questTypeLabel(_ label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(color.opacity(0.6))
                .frame(width: 3, height: 12)
                .clipShape(Capsule())
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(color.opacity(0.8))
        }
        .padding(.leading, 24)
        .padding(.vertical, 3)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 8))
    }

    @ViewBuilder
    private func storyRow(_ story: Story) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if !story.isMainQuest {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(.secondary)
                    }
                    Text(story.name).font(.subheadline.bold())
                }
                HStack(spacing: 6) {
                    Text("Lv \(story.level)").font(.caption).foregroundStyle(.secondary)
                    if !story.npcEntries.isEmpty {
                        Text("\(story.npcEntries.count) NPCs")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if story.status != .active {
                Image(systemName: story.status.systemImage)
                    .foregroundStyle(story.status.color).font(.caption)
            }
        }
        .padding(.vertical, 4)
        .padding(.leading, 24)
    }

    private func toggleCountry(_ id: UUID) {
        if expandedCountries.contains(id) { expandedCountries.remove(id) }
        else { expandedCountries.insert(id) }
    }

    private func toggleCity(_ id: UUID) {
        if expandedCities.contains(id) { expandedCities.remove(id) }
        else { expandedCities.insert(id) }
    }
}

enum QuestTypeFilter { case all, main, side }

// MARK: - CountryStoryHeader

struct CountryStoryHeader: View {
    let country: Country
    let storyCount: Int
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
            Text(country.name).font(.subheadline.bold())
            Spacer()
            if storyCount > 0 {
                Text("\(storyCount)")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2)).clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - CityStoryHeader

struct CityStoryHeader: View {
    let cityName: String
    let storyCount: Int
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
            if storyCount > 0 {
                Text("\(storyCount)")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15)).clipShape(Capsule())
            }
        }
        .padding(.leading, 16).padding(.vertical, 3)
    }
}

// MARK: - QuestProgressHeader

struct QuestProgressHeader: View {
    let mainTotal: Int
    let mainCompleted: Int
    let allTotal: Int
    let allCompleted: Int

    var mainPercent: Double { mainTotal > 0 ? Double(mainCompleted) / Double(mainTotal) : 0 }
    var allPercent: Double { allTotal > 0 ? Double(allCompleted) / Double(allTotal) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if mainTotal > 0 {
                progressRow(label: "Main Quests", completed: mainCompleted, total: mainTotal, percent: mainPercent, color: .orange)
            }
            progressRow(label: "All Quests", completed: allCompleted, total: allTotal, percent: allPercent, color: .blue)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    @ViewBuilder
    private func progressRow(label: String, completed: Int, total: Int, percent: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption2.bold()).foregroundStyle(.secondary)
                Spacer()
                Text("\(completed)/\(total)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                Text("(\(Int(percent * 100))%)").font(.caption2.monospacedDigit()).foregroundStyle(color)
            }
            ProgressView(value: percent).tint(color).scaleEffect(x: 1, y: 0.8)
        }
    }
}

// MARK: - StoryDetailView

struct StoryDetailView: View {
    @Bindable var story: Story
    let allNPCs: [NPCTemplate]
    let allStories: [Story]
    let campaign: Campaign
    let countries: [Country]
    let cities: [City]
    @Bindable var sectionState: SectionState
    @Query private var pcs: [PlayerCharacter]
    @Query private var encounters: [SavedEncounter]
    @Query private var allShops: [Shop]

    @Environment(\.modelContext) private var modelContext
    @StateObject private var catalog = CatalogService.shared
    @State private var showNPCPicker = false
    @State private var showPrereqPicker = false
    @State private var showEncounterPicker = false
    @State private var showItemPicker = false
    @State private var showShopPicker = false
    @State private var showCreateShop = false

    init(story: Story, allNPCs: [NPCTemplate], allStories: [Story], campaign: Campaign, countries: [Country], cities: [City], sectionState: SectionState) {
        _story = Bindable(story)
        self.allNPCs = allNPCs
        self.allStories = allStories
        self.campaign = campaign
        self.countries = countries
        self.cities = cities
        _sectionState = Bindable(sectionState)
        let cid = campaign.id
        _pcs = Query(filter: #Predicate<PlayerCharacter> { $0.campaignID == cid })
        _encounters = Query(filter: #Predicate<SavedEncounter> { $0.campaignID == cid }, sort: [SortDescriptor(\SavedEncounter.name)])
        _allShops = Query(filter: #Predicate<Shop> { $0.campaignID == cid }, sort: [SortDescriptor(\Shop.name)])
    }

    var prerequisites: [Story] {
        story.prerequisiteStoryIDs.compactMap { id in allStories.first { $0.id == id } }
    }

    var linkedShops: [Shop] {
        allShops.filter { $0.storyID == story.id }
    }

    var locationCity: City? { cities.first { $0.id == story.locationCityID } }
    var locationCountry: Country? {
        guard let city = locationCity else { return nil }
        return countries.first { $0.id == city.countryID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Story name", text: $story.name)
                            .font(.title2.bold()).textFieldStyle(.plain)
                        HStack(spacing: 8) {
                            Text("Level").font(.callout).foregroundStyle(.secondary)
                            Stepper(value: $story.level, in: 1...20) {
                                Text("\(story.level)").font(.callout.bold()).frame(width: 28)
                            }
                        }
                    }
                    Spacer()
                    Picker("", selection: Binding(get: { story.status }, set: { story.status = $0 })) {
                        ForEach(StoryStatus.allCases) { s in
                            Label(s.rawValue, systemImage: s.systemImage).tag(s)
                        }
                    }
                    .pickerStyle(.menu).tint(story.status.color).labelsHidden()
                }
                .onChange(of: story.status) { _, newStatus in
                    if newStatus == .completed && !story.xpAwarded && campaign.trackXP && story.rewardXP > 0 {
                        for pc in pcs { pc.currentXP += story.rewardXP }
                        story.xpAwarded = true
                    }
                }

                HStack(spacing: 10) {
                    questTypeCard(title: "Main Quest", icon: "star.fill", isSelected: story.isMainQuest, color: .orange) {
                        story.isMainQuest = true
                    }
                    questTypeCard(title: "Side Quest", icon: "diamond.fill", isSelected: !story.isMainQuest, color: .indigo) {
                        story.isMainQuest = false
                    }
                }

                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.secondary).font(.subheadline).frame(width: 18)
                        Text("Location").font(.callout).foregroundStyle(.secondary)
                        Spacer()
                        Menu {
                            Button("None") { story.locationCityID = nil }
                            Divider()
                            ForEach(countries) { country in
                                let countryCities = cities.filter { $0.countryID == country.id }
                                if !countryCities.isEmpty {
                                    Menu(country.name) {
                                        ForEach(countryCities) { city in
                                            Button {
                                                story.locationCityID = city.id
                                            } label: {
                                                if story.locationCityID == city.id {
                                                    Label(city.name, systemImage: "checkmark")
                                                } else {
                                                    Text(city.name)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if let city = locationCity {
                                    Text(locationCountry != nil ? "\(locationCountry!.name) › \(city.name)" : city.name)
                                        .font(.callout).foregroundStyle(.primary)
                                } else {
                                    Text("None").font(.callout).foregroundStyle(.tertiary)
                                }
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)

                    if campaign.trackXP {
                        Divider().padding(.leading, 40)
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.secondary).font(.subheadline).frame(width: 18)
                            Text("XP Reward").font(.callout).foregroundStyle(.secondary)
                            Spacer()
                            if story.xpAwarded {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green).font(.caption).help("XP already awarded")
                            }
                            TextField("0", value: $story.rewardXP, format: .number)
                                .textFieldStyle(.roundedBorder).frame(width: 72)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1))
                )

                Divider()

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Description", systemImage: "text.alignleft")
                            .font(.caption.bold()).foregroundStyle(.secondary)
                        TextEditor(text: $story.storyDescription)
                            .font(.callout).frame(minHeight: 160).scrollContentBackground(.hidden)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Prerequisites", systemImage: "arrow.triangle.branch")
                                .font(.caption.bold()).foregroundStyle(.secondary)
                            Spacer()
                            Button { showPrereqPicker = true } label: {
                                Image(systemName: "plus.circle").font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        if prerequisites.isEmpty {
                            Text("No prerequisites").font(.caption).foregroundStyle(.tertiary).padding(.vertical, 4)
                        } else {
                            ForEach(prerequisites) { prereq in
                                HStack(spacing: 10) {
                                    Image(systemName: prereq.status.systemImage)
                                        .foregroundStyle(prereq.status.color).font(.subheadline)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(prereq.name).font(.subheadline)
                                        Text(prereq.status.rawValue).font(.caption).foregroundStyle(prereq.status.color)
                                    }
                                    Spacer()
                                    Button { story.prerequisiteStoryIDs.removeAll { $0 == prereq.id } } label: {
                                        Image(systemName: "xmark.circle").font(.caption).foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Linked Encounters", systemImage: "checklist")
                                .font(.caption.bold()).foregroundStyle(.secondary)
                            Spacer()
                            Button { showEncounterPicker = true } label: {
                                Image(systemName: "plus.circle").font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        if story.linkedEncounters.isEmpty {
                            Text("No encounters linked").font(.caption).foregroundStyle(.tertiary).padding(.vertical, 4)
                        } else {
                            ForEach(story.linkedEncounters) { entry in
                                HStack(spacing: 8) {
                                    Button {
                                        var entries = story.linkedEncounters
                                        if let i = entries.firstIndex(where: { $0.id == entry.id }) {
                                            entries[i].isCompleted.toggle()
                                            story.linkedEncounters = entries
                                        }
                                    } label: {
                                        Image(systemName: entry.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(entry.isCompleted ? .green : .secondary)
                                            .font(.subheadline)
                                    }
                                    .buttonStyle(.plain)
                                    Text(entry.encounterName)
                                        .font(.subheadline)
                                        .strikethrough(entry.isCompleted, color: .secondary)
                                        .foregroundStyle(entry.isCompleted ? .secondary : .primary)
                                    Spacer()
                                    if let enc = encounters.first(where: { $0.id == entry.encounterID }) {
                                        Button {
                                            sectionState.selectedEncounter = enc
                                            sectionState.selectedSection = .encounterBuilder
                                        } label: {
                                            Image(systemName: "arrow.right.circle.fill")
                                                .foregroundStyle(.orange).font(.caption)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Go to encounter")
                                    }
                                    Button {
                                        story.linkedEncounters.removeAll { $0.id == entry.id }
                                    } label: {
                                        Image(systemName: "minus.circle").font(.caption).foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("NPCs", systemImage: "person.2.fill")
                                .font(.caption.bold()).foregroundStyle(.secondary)
                            Spacer()
                            Button { showNPCPicker = true } label: {
                                Image(systemName: "plus.circle").font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        if story.npcEntries.isEmpty {
                            Text("No NPCs linked").font(.caption).foregroundStyle(.tertiary).padding(.vertical, 4)
                        } else {
                            ForEach(story.npcEntries) { entry in
                                HStack {
                                    Image(systemName: "person.circle.fill").foregroundStyle(.teal).font(.caption)
                                    Text(entry.npcName).font(.subheadline)
                                    Spacer()
                                    Button { story.npcEntries.removeAll { $0.id == entry.id } } label: {
                                        Image(systemName: "minus.circle").font(.caption).foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Story Items", systemImage: "sparkles")
                                .font(.caption.bold()).foregroundStyle(.secondary)
                            Spacer()
                            Button { showItemPicker = true } label: {
                                Image(systemName: "plus.circle").font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        if story.linkedItems.isEmpty {
                            Text("No items linked").font(.caption).foregroundStyle(.tertiary).padding(.vertical, 4)
                        } else {
                            ForEach(story.linkedItems) { entry in
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(entry.itemType.accentColor.opacity(0.15))
                                            .frame(width: 22, height: 22)
                                        Image(systemName: entry.itemType.icon)
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(entry.itemType.accentColor)
                                    }
                                    Text(entry.name).font(.subheadline)
                                    Spacer()
                                    Button {
                                        var items = story.linkedItems
                                        if let i = items.firstIndex(where: { $0.id == entry.id }) {
                                            items[i].isReward.toggle()
                                            story.linkedItems = items
                                        }
                                    } label: {
                                        Text(entry.isReward ? "Reward" : "Required")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 5).padding(.vertical, 2)
                                            .background(entry.isReward ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                            .foregroundStyle(entry.isReward ? .green : .orange)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    Button { story.linkedItems.removeAll { $0.id == entry.id } } label: {
                                        Image(systemName: "minus.circle").font(.caption).foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Linked Shops", systemImage: "storefront.fill")
                                .font(.caption.bold()).foregroundStyle(.secondary)
                            Spacer()
                            Menu {
                                Button { showShopPicker = true } label: {
                                    Label("Link Existing Shop", systemImage: "storefront")
                                }
                                Button { showCreateShop = true } label: {
                                    Label("Create New Shop", systemImage: "plus.circle")
                                }
                            } label: {
                                Image(systemName: "plus.circle").font(.caption)
                            }
                            .menuStyle(.borderlessButton).fixedSize()
                        }
                        if linkedShops.isEmpty {
                            Text("No shops linked").font(.caption).foregroundStyle(.tertiary).padding(.vertical, 4)
                        } else {
                            ForEach(linkedShops) { shop in
                                HStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(shop.shopType.accentColor.opacity(0.15))
                                            .frame(width: 28, height: 28)
                                        Image(systemName: shop.shopType.icon)
                                            .font(.caption.bold())
                                            .foregroundStyle(shop.shopType.accentColor)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(shop.name).font(.subheadline)
                                        Text(shop.shopType.rawValue).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if !shop.ownerName.isEmpty {
                                        Text(shop.ownerName).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Button {
                                        sectionState.selectedShop = shop
                                        sectionState.selectedSection = .shops
                                    } label: {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .foregroundStyle(.orange).font(.caption)
                                    }
                                    .buttonStyle(.plain).help("Open shop")
                                    Button {
                                        shop.storyID = nil
                                        shop.linkedStoryName = ""
                                    } label: {
                                        Image(systemName: "minus.circle").font(.caption).foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
        }
        .task { await catalog.load() }
        .sheet(isPresented: $showNPCPicker) {
            StoryNPCPickerSheet(
                allNPCs: allNPCs,
                linkedNPCIDs: Set(story.npcEntries.map { $0.npcID }),
                campaignID: campaign.id
            ) { npc in
                guard !story.npcEntries.contains(where: { $0.npcID == npc.id }) else { return }
                story.npcEntries.append(StoryNPCEntry(npcID: npc.id, npcName: npc.name))
            }
        }
        .sheet(isPresented: $showPrereqPicker) {
            PrerequisitePickerSheet(
                stories: allStories.filter { $0.id != story.id },
                selectedIDs: Set(story.prerequisiteStoryIDs)
            ) { ids in
                story.prerequisiteStoryIDs = Array(ids)
            }
        }
        .sheet(isPresented: $showEncounterPicker) {
            EncounterLinkerSheet(
                encounters: encounters,
                linkedIDs: Set(story.linkedEncounters.map { $0.encounterID })
            ) { selected in
                for enc in selected {
                    guard !story.linkedEncounters.contains(where: { $0.encounterID == enc.id }) else { continue }
                    story.linkedEncounters.append(StoryEncounterEntry(encounterID: enc.id, encounterName: enc.name))
                }
            }
        }
        .sheet(isPresented: $showItemPicker) {
            CatalogBrowserView(campaignID: campaign.id) { item in
                guard !story.linkedItems.contains(where: { $0.slug == item.slug }) else { return }
                var items = story.linkedItems
                items.append(StoryItemEntry(slug: item.slug, name: item.name, itemTypeRaw: item.type.rawValue))
                story.linkedItems = items
            }
        }
        .sheet(isPresented: $showShopPicker) {
            StoryShopPickerSheet(
                shops: allShops.filter { $0.campaignID == campaign.id && $0.storyID != story.id }
            ) { shop in
                shop.storyID = story.id
                shop.linkedStoryName = story.name
            }
        }
        .sheet(isPresented: $showCreateShop) {
            AddShopSheet(
                campaignID: campaign.id,
                cities: cities,
                countries: countries,
                prefilledCityID: story.locationCityID
            ) { shop in
                shop.storyID = story.id
                shop.linkedStoryName = story.name
            }
        }
    }

    @ViewBuilder
    private func questTypeCard(title: String, icon: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption.bold())
                Text(title).font(.subheadline.bold())
            }
            .foregroundStyle(isSelected ? .white : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color : color.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(color.opacity(isSelected ? 0 : 0.25), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PrerequisitePickerSheet

struct PrerequisitePickerSheet: View {
    let stories: [Story]
    let selectedIDs: Set<UUID>
    let onConfirm: (Set<UUID>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selection: Set<UUID>

    init(stories: [Story], selectedIDs: Set<UUID>, onConfirm: @escaping (Set<UUID>) -> Void) {
        self.stories = stories; self.selectedIDs = selectedIDs; self.onConfirm = onConfirm
        _selection = State(initialValue: selectedIDs)
    }

    var filtered: [Story] {
        search.isEmpty ? stories : stories.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Prerequisites").font(.headline)
                Spacer()
                Button("Done") { onConfirm(selection); dismiss() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            Divider()
            TextField("Search stories...", text: $search)
                .textFieldStyle(.roundedBorder).padding(.horizontal, 16).padding(.vertical, 10)
            Divider()
            List {
                ForEach(filtered) { story in
                    let isSelected = selection.contains(story.id)
                    Button {
                        if isSelected { selection.remove(story.id) } else { selection.insert(story.id) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? .blue : .secondary).font(.subheadline)
                            Image(systemName: story.status.systemImage)
                                .foregroundStyle(story.status.color).font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(story.name).font(.subheadline)
                                Text("Level \(story.level)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if filtered.isEmpty {
                    Text("No stories available")
                        .foregroundStyle(.secondary).font(.callout)
                        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 20)
                }
            }
        }
        .frame(width: 360, height: 420)
    }
}

// MARK: - StoryNPCPickerSheet

struct StoryNPCPickerSheet: View {
    let allNPCs: [NPCTemplate]
    let linkedNPCIDs: Set<UUID>
    let campaignID: UUID
    let onAdd: (NPCTemplate) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var showCreateForm = false
    @State private var newNPCName = ""

    var filtered: [NPCTemplate] {
        search.isEmpty ? allNPCs : allNPCs.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add NPC").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.borderless)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            Divider()
            VStack(spacing: 0) {
                if showCreateForm {
                    HStack(spacing: 8) {
                        TextField("NPC name", text: $newNPCName).textFieldStyle(.roundedBorder)
                        Button("Create") {
                            let npc = NPCTemplate(name: newNPCName.isEmpty ? "New NPC" : newNPCName, maxHP: 10, armorClass: 10, campaignID: campaignID)
                            modelContext.insert(npc); onAdd(npc); newNPCName = ""; showCreateForm = false
                        }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                        Button("Cancel") { showCreateForm = false }.buttonStyle(.borderless).controlSize(.small)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                } else {
                    Button { showCreateForm = true } label: {
                        Label("Create New NPC", systemImage: "plus.circle.fill").font(.callout).foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain).padding(.horizontal, 16).padding(.vertical, 10)
                }
                Divider()
                TextField("Search existing NPCs...", text: $search)
                    .textFieldStyle(.roundedBorder).padding(.horizontal, 16).padding(.vertical, 8)
                Divider()
            }
            List {
                ForEach(filtered) { npc in
                    let isLinked = linkedNPCIDs.contains(npc.id)
                    Button { onAdd(npc) } label: {
                        HStack {
                            Text(npc.name).font(.subheadline)
                            Spacer()
                            if isLinked { Image(systemName: "checkmark").foregroundStyle(.green).font(.caption) }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).disabled(isLinked)
                }
                if filtered.isEmpty {
                    Text("No NPCs in library").foregroundStyle(.secondary).font(.callout)
                        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 16)
                }
            }
        }
        .frame(width: 360, height: 460)
    }
}

// MARK: - AddStorySheet

struct AddStorySheet: View {
    let campaignID: UUID
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var level = 1

    var body: some View {
        VStack(spacing: 20) {
            Text("New Story").font(.headline)
            TextField("Story name", text: $name).textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                Text("Level").font(.callout).foregroundStyle(.secondary)
                Stepper(value: $level, in: 1...20) {
                    Text("\(level)").font(.callout.bold()).frame(width: 28)
                }
            }
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add") {
                    let story = Story(name: name.isEmpty ? "New Story" : name, campaignID: campaignID)
                    story.level = level
                    modelContext.insert(story)
                    dismiss()
                }
                .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24).frame(width: 320)
    }
}

// MARK: - EncounterLinkerSheet

struct EncounterLinkerSheet: View {
    let encounters: [SavedEncounter]
    let linkedIDs: Set<UUID>
    let onAdd: ([SavedEncounter]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selected: Set<UUID> = []

    var available: [SavedEncounter] {
        let unlinked = encounters.filter { !linkedIDs.contains($0.id) }
        if search.isEmpty { return unlinked }
        return unlinked.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Link Encounters").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.borderless)
                if !selected.isEmpty {
                    Button("Add (\(selected.count))") {
                        let toAdd = encounters.filter { selected.contains($0.id) }
                        onAdd(toAdd)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            Divider()

            TextField("Search encounters…", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16).padding(.vertical, 10)

            Divider()

            List {
                ForEach(available) { enc in
                    let isSelected = selected.contains(enc.id)
                    Button {
                        if isSelected { selected.remove(enc.id) } else { selected.insert(enc.id) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? .blue : .secondary).font(.subheadline)
                            Text(enc.name).font(.subheadline)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if available.isEmpty {
                    Text(encounters.filter { !linkedIDs.contains($0.id) }.isEmpty ? "All encounters already linked" : "No matches")
                        .foregroundStyle(.secondary).font(.callout)
                        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 20)
                }
            }
        }
        .frame(width: 360, height: 420)
    }
}

// MARK: - StoryShopPickerSheet

struct StoryShopPickerSheet: View {
    let shops: [Shop]
    let onLink: (Shop) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var filtered: [Shop] {
        search.isEmpty ? shops : shops.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Link Shop").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.borderless)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            Divider()
            TextField("Search shops...", text: $search)
                .textFieldStyle(.roundedBorder).padding(.horizontal, 16).padding(.vertical, 10)
            Divider()
            List {
                ForEach(filtered) { shop in
                    Button {
                        onLink(shop)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(shop.shopType.accentColor.opacity(0.15))
                                    .frame(width: 28, height: 28)
                                Image(systemName: shop.shopType.icon)
                                    .font(.caption.bold())
                                    .foregroundStyle(shop.shopType.accentColor)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(shop.name).font(.subheadline)
                                Text(shop.shopType.rawValue).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if filtered.isEmpty {
                    Text("No shops available")
                        .foregroundStyle(.secondary).font(.callout)
                        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 20)
                }
            }
        }
        .frame(width: 360, height: 420)
    }
}

// MARK: - Story Export

struct LinkedEncounterExport: Codable {
    var name: String
    var completed: Bool
}

struct StoryExportDTO: Codable {
    var name: String
    var status: String
    var type: String
    var level: Int
    var description: String
    var rewardXP: Int
    var xpAwarded: Bool
    var location: String?
    var npcs: [String]
    var linkedEncounters: [LinkedEncounterExport]
    var prerequisiteStoryNames: [String]
}

struct StoryExportBundle: Codable {
    var campaignName: String
    var exportedAt: String
    var totalStories: Int
    var stories: [StoryExportDTO]
}

struct StoryExportFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
