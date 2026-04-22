import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

@Observable final class SectionState {
    var selectedSection: NavigationSection? = .dmControl
    var selectedStory: Story? = nil
    var selectedCity: City? = nil
    var selectedEncounter: SavedEncounter? = nil
    var selectedPC: PlayerCharacter? = nil
    var selectedNPC: NPCTemplate? = nil
    var selectedMonster: MonsterTemplate? = nil
    var selectedShop: Shop? = nil
    var expandedWorldCountries: Set<UUID> = []
}

enum NavigationSection: String, CaseIterable, Identifiable {
    case dmControl = "DM Control"
    case pcLibrary = "PC Library"
    case npcLibrary = "NPC Library"
    case bestiary = "Bestiary"
    case encounterBuilder = "Encounter Builder"
    case activeCombat = "Active Combat"
    case world = "World"
    case stories = "Stories"
    case worldMap = "World Map"
    case shops = "Shops"
    case gallery = "Gallery"
    case xpIndex = "XP Index"
    case catalog = "Catalog"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dmControl: return "person.badge.shield.checkmark.fill"
        case .pcLibrary: return "person.2.fill"
        case .npcLibrary: return "person.2.circle.fill"
        case .bestiary: return "book.closed.fill"
        case .encounterBuilder: return "checklist"
        case .activeCombat: return "bolt.circle.fill"
        case .world: return "globe.europe.africa.fill"
        case .stories: return "scroll.fill"
        case .worldMap: return "map.fill"
        case .shops: return "storefront.fill"
        case .gallery: return "photo.stack.fill"
        case .xpIndex: return "chart.bar.fill"
        case .catalog: return "books.vertical.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .dmControl: return Color(red: 0.2, green: 0.75, blue: 0.5)
        case .pcLibrary: return Color(red: 0.36, green: 0.61, blue: 1.0)
        case .npcLibrary: return Color(red: 0.2, green: 0.72, blue: 0.44)
        case .bestiary: return Color(red: 0.95, green: 0.35, blue: 0.35)
        case .encounterBuilder: return Color(red: 0.95, green: 0.65, blue: 0.2)
        case .activeCombat: return Color(red: 0.7, green: 0.45, blue: 1.0)
        case .world: return Color(red: 0.2, green: 0.6, blue: 0.9)
        case .stories: return Color(red: 0.75, green: 0.5, blue: 0.25)
        case .worldMap: return Color(red: 0.18, green: 0.5, blue: 0.35)
        case .shops: return Color(red: 0.6, green: 0.45, blue: 0.25)
        case .gallery: return Color(red: 0.75, green: 0.45, blue: 0.15)
        case .xpIndex: return Color(red: 0.2, green: 0.78, blue: 0.45)
        case .catalog: return Color(red: 0.45, green: 0.35, blue: 0.75)
        }
    }
}

struct ContentView: View {
    @Bindable var campaign: Campaign
    var onChangeCampaign: () -> Void

    @State private var combatEngine = CombatEngine()
    @State private var showCampaignSettings: Bool = false
    @State private var sectionState = SectionState()
    @AppStorage("externalAppPath") private var externalAppPath: String = ""
    @State private var showAppPicker: Bool = false

    var body: some View {
        NavigationSplitView {
            List(NavigationSection.allCases, selection: Bindable(sectionState).selectedSection) { section in
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(section.accentColor.gradient)
                            .frame(width: 28, height: 28)
                        Image(systemName: section.systemImage)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    Text(section.rawValue)
                        .font(.callout.bold())
                }
                .padding(.vertical, 3)
                .tag(section)
            }
            .navigationTitle(campaign.name)
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Button {
                        showCampaignSettings = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "gear")
                                .foregroundStyle(.secondary)
                            Text("Campaign Settings")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderless)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    externalAppButton

                    Divider()

                    Button {
                        onChangeCampaign()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left.circle.fill")
                                .foregroundStyle(.secondary)
                            Text("Change Campaign")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderless)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } detail: {
            Group {
                switch sectionState.selectedSection {
                case .dmControl:
                    DMControlView(campaign: campaign)
                case .pcLibrary:
                    PCLibraryView(campaign: campaign, sectionState: sectionState)
                case .npcLibrary:
                    NPCLibraryView(campaign: campaign, sectionState: sectionState)
                case .bestiary:
                    BestiaryView(campaign: campaign, sectionState: sectionState)
                case .encounterBuilder:
                    EncounterBuilderView(
                        campaign: campaign,
                        sectionState: sectionState,
                        combatEngine: combatEngine
                    ) {
                        sectionState.selectedSection = .activeCombat
                    }
                case .activeCombat:
                    ActiveCombatView(campaign: campaign, combatEngine: combatEngine)
                case .world:
                    WorldView(campaign: campaign, sectionState: sectionState)
                case .stories:
                    StoriesView(campaign: campaign, sectionState: sectionState)
                case .worldMap:
                    WorldMapView(campaign: campaign)
                case .shops:
                    ShopsView(campaign: campaign, sectionState: sectionState)
                case .gallery:
                    GalleryView(campaign: campaign)
                case .xpIndex:
                    XPIndexView(campaign: campaign)
                case .catalog:
                    CatalogView(campaign: campaign)
                case nil:
                    ContentUnavailableView(
                        "Select a Section",
                        systemImage: "sidebar.left",
                        description: Text("Choose a section from the sidebar to get started.")
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.indigo)
        .sheet(isPresented: $showCampaignSettings) {
            CampaignSettingsSheet(campaign: campaign)
        }
        .fileImporter(
            isPresented: $showAppPicker,
            allowedContentTypes: [UTType.application],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                externalAppPath = url.path
            }
        }
    }

    @ViewBuilder
    private var externalAppButton: some View {
        let appName: String = externalAppPath.isEmpty
            ? "Music App"
            : URL(fileURLWithPath: externalAppPath).deletingPathExtension().lastPathComponent

        Button {
            if externalAppPath.isEmpty {
                showAppPicker = true
            } else {
                NSWorkspace.shared.open(URL(fileURLWithPath: externalAppPath))
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                    .foregroundStyle(externalAppPath.isEmpty ? Color.secondary : Color.purple)
                Text(appName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderless)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            if !externalAppPath.isEmpty {
                Button("Open \(appName)") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: externalAppPath))
                }
                Divider()
            }
            Button(externalAppPath.isEmpty ? "Choose App…" : "Change App…") {
                showAppPicker = true
            }
            if !externalAppPath.isEmpty {
                Button("Remove", role: .destructive) {
                    externalAppPath = ""
                }
            }
        }
    }
}

struct CampaignSettingsSheet: View {
    @Bindable var campaign: Campaign
    @Environment(\.dismiss) private var dismiss

    @Query private var players: [PlayerCharacter]
    @Query private var npcs: [NPCTemplate]
    @Query private var monsters: [MonsterTemplate]
    @Query private var folders: [EncounterFolder]
    @Query private var encounters: [SavedEncounter]
    @Query private var countries: [Country]
    @Query private var cities: [City]
    @Query private var allStoryPins: [StoryPin]
    @Query private var allShopPins: [ShopPin]
    @Query private var stories: [Story]
    @Query private var shops: [Shop]
    @Query private var customCatalogItems: [CustomCatalogItem]
    @Query private var wishlistItems: [PCWishlistItem]
    @Query private var worldMaps: [WorldMapRecord]
    @Query private var galleryFolders: [GalleryFolder]
    @Query private var galleryImages: [GalleryImage]

    @State private var exportError: String?

    init(campaign: Campaign) {
        _campaign = Bindable(campaign)
        let cid = campaign.id
        _players   = Query(filter: #Predicate<PlayerCharacter> { $0.campaignID == cid })
        _npcs      = Query(filter: #Predicate<NPCTemplate>     { $0.campaignID == cid })
        _monsters  = Query(filter: #Predicate<MonsterTemplate> { $0.campaignID == cid && !$0.isGlobal })
        _folders   = Query(filter: #Predicate<EncounterFolder> { $0.campaignID == cid })
        _encounters = Query(filter: #Predicate<SavedEncounter> { $0.campaignID == cid })
        _countries = Query(filter: #Predicate<Country>         { $0.campaignID == cid })
        _cities    = Query(filter: #Predicate<City>            { $0.campaignID == cid })
        _allStoryPins = Query()
        _allShopPins  = Query()
        _stories   = Query(filter: #Predicate<Story>           { $0.campaignID == cid })
        _shops     = Query(filter: #Predicate<Shop>            { $0.campaignID == cid })
        _customCatalogItems = Query(filter: #Predicate<CustomCatalogItem> { $0.campaignID == cid })
        _wishlistItems      = Query(filter: #Predicate<PCWishlistItem>    { $0.campaignID == cid })
        _worldMaps = Query(filter: #Predicate<WorldMapRecord>  { $0.campaignID == cid })
        _galleryFolders = Query(filter: #Predicate<GalleryFolder> { $0.campaignID == cid })
        _galleryImages  = Query(filter: #Predicate<GalleryImage>  { $0.campaignID == cid })
    }

    private var storyPins: [StoryPin] {
        let cityIDs = Set(cities.map { $0.id })
        return allStoryPins.filter { cityIDs.contains($0.cityID) }
    }

    private var shopPins: [ShopPin] {
        let cityIDs = Set(cities.map { $0.id })
        return allShopPins.filter { cityIDs.contains($0.cityID) }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Image(systemName: "gear")
                    .font(.system(size: 32)).foregroundStyle(.secondary)
                Text("Campaign Settings").font(.title2.bold())
            }
            .padding(.top, 24).padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Experience Points", systemImage: "sparkles")
                            .font(.caption.bold()).foregroundStyle(.secondary)
                        Toggle("Track XP", isOn: $campaign.trackXP)
                        Text("When disabled, defeating enemies won't award XP.")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 28).padding(.vertical, 18)

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Initiative Roll", systemImage: "dice.fill")
                            .font(.caption.bold()).foregroundStyle(.secondary)
                        Toggle("Auto-roll d20 for enemies", isOn: $campaign.autoRollInitiative)
                        Text("Automatically generates a random d20 roll (no bonus) for each enemy when the initiative sheet opens.")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 28).padding(.vertical, 18)

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Default Enemy HP", systemImage: "heart.fill")
                            .font(.caption.bold()).foregroundStyle(.secondary)
                        Picker("", selection: $campaign.defaultHPMode) {
                            Text("Average").tag("Average")
                            Text("Roll Dice").tag("Roll")
                            Text("Manual").tag("Manual")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text("Pre-selects how monster HP is determined in the initiative sheet.")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 28).padding(.vertical, 18)

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Backup & Transfer", systemImage: "square.and.arrow.up")
                            .font(.caption.bold()).foregroundStyle(.secondary)
                        Text("Export all campaign data — characters, bestiary, encounters, world, stories, and maps — as a JSON file that can be imported on any device.")
                            .font(.caption).foregroundStyle(.tertiary)
                        Button {
                            exportCampaign()
                        } label: {
                            Label("Export Campaign…", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        if let err = exportError {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 28).padding(.vertical, 18)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(width: 460, height: 440)
    }

    private func exportCampaign() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(campaign.name).json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try exportCampaignBundle(
                    campaign: campaign,
                    players: players,
                    npcs: npcs,
                    monsters: monsters,
                    folders: folders,
                    encounters: encounters,
                    countries: countries,
                    cities: cities,
                    storyPins: storyPins,
                    shopPins: shopPins,
                    stories: stories,
                    shops: shops,
                    customCatalogItems: customCatalogItems,
                    wishlistItems: wishlistItems,
                    worldMap: worldMaps.first,
                    galleryFolders: galleryFolders,
                    galleryImages: galleryImages
                )
                try data.write(to: url)
            } catch {
                exportError = "Export failed: \(error.localizedDescription)"
            }
        }
    }
}
