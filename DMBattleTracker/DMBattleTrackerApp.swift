import SwiftUI
import SwiftData

@main
struct DMBattleTrackerApp: App {
    let container: ModelContainer = {
        let schema = Schema([Campaign.self, PlayerCharacter.self, MonsterTemplate.self, NPCTemplate.self, SavedEncounter.self, EncounterFolder.self, Country.self, City.self, StoryPin.self, ShopPin.self, Story.self, WorldMapRecord.self, GalleryFolder.self, GalleryImage.self, Shop.self, PCWishlistItem.self, CustomCatalogItem.self])
        let config = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let storeURL = config.url
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + "-shm"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + "-wal"))
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    @State private var presentationState = GalleryPresentationState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .environment(presentationState)
        }
        .modelContainer(container)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Window("Gallery Presentation", id: "gallery-presentation") {
            GalleryPresentationWindowView()
                .environment(presentationState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1280, height: 800)
    }
}

struct RootView: View {
    @State private var selectedCampaign: Campaign? = nil

    var body: some View {
        Group {
            if let campaign = selectedCampaign {
                ContentViewWrapper(campaign: campaign) {
                    selectedCampaign = nil
                }
            } else {
                CampaignSelectionView { campaign in
                    selectedCampaign = campaign
                }
            }
        }
    }
}

struct ContentViewWrapper: View {
    @Bindable var campaign: Campaign
    var onChangeCampaign: () -> Void

    var body: some View {
        ContentView(campaign: campaign, onChangeCampaign: onChangeCampaign)
    }
}
