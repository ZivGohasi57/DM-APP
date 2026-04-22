import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct WorldView: View {
    let campaign: Campaign
    @Bindable var sectionState: SectionState
    @Environment(\.modelContext) private var modelContext
    @Query private var countries: [Country]
    @Query private var cities: [City]
    @Query private var stories: [Story]
    @Query private var pins: [StoryPin]
    @Query private var shopPins: [ShopPin]
    @Query private var shops: [Shop]

    @State private var selectedCity: City?
    @State private var showAddCountry = false
    @State private var targetCountryForCity: Country?
    @State private var cityToDelete: City? = nil
    @State private var countryToDelete: Country? = nil

    init(campaign: Campaign, sectionState: SectionState) {
        self.campaign = campaign
        self.sectionState = sectionState
        let cid = campaign.id
        _countries = Query(
            filter: #Predicate<Country> { $0.campaignID == cid },
            sort: [SortDescriptor(\Country.sortOrder), SortDescriptor(\Country.name)]
        )
        _cities = Query(
            filter: #Predicate<City> { $0.campaignID == cid },
            sort: [SortDescriptor(\City.name)]
        )
        _stories = Query(
            filter: #Predicate<Story> { $0.campaignID == cid },
            sort: [SortDescriptor(\Story.name)]
        )
        _pins = Query(sort: [SortDescriptor(\StoryPin.id)])
        _shopPins = Query(sort: [SortDescriptor(\ShopPin.id)])
        _shops = Query(
            filter: #Predicate<Shop> { $0.campaignID == cid },
            sort: [SortDescriptor(\Shop.name)]
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selectedCity) {
                ForEach(countries) { country in
                    let isExpanded = sectionState.expandedWorldCountries.contains(country.id)
                    let countryCities = cities.filter { $0.countryID == country.id }
                    Section {
                        if isExpanded {
                            ForEach(countryCities) { city in
                                HStack(spacing: 6) {
                                    Label(city.name, systemImage: "building.2.fill")
                                    Spacer()
                                    let storyCount = pins.filter { $0.cityID == city.id }.count
                                    let cityStoryIDs = Set(stories.filter { $0.locationCityID == city.id }.map { $0.id })
                                    let shopCount: Int = {
                                        var ids = Set(shopPins.filter { $0.cityID == city.id }.compactMap { pin in
                                            shops.first { $0.id == pin.shopID }?.id
                                        })
                                        for shop in shops where shop.storyID != nil {
                                            if let sid = shop.storyID, cityStoryIDs.contains(sid) {
                                                ids.insert(shop.id)
                                            }
                                        }
                                        return ids.count
                                    }()
                                    if storyCount > 0 {
                                        HStack(spacing: 2) {
                                            Image(systemName: "scroll.fill")
                                                .font(.system(size: 8))
                                                .foregroundStyle(.indigo)
                                            Text("\(storyCount)")
                                                .font(.caption2.monospacedDigit().bold())
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    if shopCount > 0 {
                                        HStack(spacing: 2) {
                                            Image(systemName: "storefront.fill")
                                                .font(.system(size: 8))
                                                .foregroundStyle(.orange)
                                            Text("\(shopCount)")
                                                .font(.caption2.monospacedDigit().bold())
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Image(systemName: city.symbolImageData != nil ? "seal.fill" : "seal")
                                        .font(.system(size: 10))
                                        .foregroundStyle(city.symbolImageData != nil ? Color.orange : Color.secondary.opacity(0.4))
                                        .help(city.symbolImageData != nil ? "Symbol attached" : "No symbol")
                                    Image(systemName: city.mapImageData != nil ? "photo.fill" : "photo")
                                        .font(.system(size: 10))
                                        .foregroundStyle(city.mapImageData != nil ? Color.blue : Color.secondary.opacity(0.4))
                                        .help(city.mapImageData != nil ? "Map attached" : "No map")
                                    Button {
                                        cityToDelete = city
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete city")
                                }
                                .tag(city)
                            }
                        }
                    } header: {
                        CountryHeaderView(
                            country: country,
                            cityCount: countryCities.count,
                            isExpanded: isExpanded,
                            onToggle: { toggleCountry(country.id, in: &sectionState.expandedWorldCountries) },
                            onAddCity: { targetCountryForCity = country },
                            onDelete: { countryToDelete = country }
                        )
                    }
                }
            }
            .frame(minWidth: 220, maxWidth: 270)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddCountry = true } label: {
                        Label("New Country", systemImage: "plus")
                    }
                }
            }

            Divider()

            Group {
                if let city = selectedCity {
                    CityMapView(
                        city: city,
                        stories: stories,
                        pins: pins.filter { $0.cityID == city.id },
                        shopPins: shopPins.filter { $0.cityID == city.id },
                        shops: shops,
                        sectionState: sectionState
                    )
                } else {
                    ContentUnavailableView(
                        "No City Selected",
                        systemImage: "map",
                        description: Text("Select a city from the sidebar to view its map.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("World")
        .sheet(isPresented: $showAddCountry) {
            AddCountrySheet(campaignID: campaign.id, sortOrder: countries.count)
        }
        .sheet(item: $targetCountryForCity) { country in
            AddCitySheet(campaignID: campaign.id, countryID: country.id)
        }
        .alert("Delete City?", isPresented: Binding(get: { cityToDelete != nil }, set: { if !$0 { cityToDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let c = cityToDelete { deleteCity(c) }
                cityToDelete = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let c = cityToDelete { Text("Delete '\(c.name)' and all its map pins? This cannot be undone.") }
        }
        .alert("Delete Country?", isPresented: Binding(get: { countryToDelete != nil }, set: { if !$0 { countryToDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let c = countryToDelete { deleteCountry(c) }
                countryToDelete = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let c = countryToDelete { Text("Delete '\(c.name)' and all its cities? This cannot be undone.") }
        }
    }

    private func toggleCountry(_ id: UUID, in set: inout Set<UUID>) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }

    private func deleteCity(_ city: City) {
        for pin in pins.filter({ $0.cityID == city.id }) { modelContext.delete(pin) }
        for pin in shopPins.filter({ $0.cityID == city.id }) { modelContext.delete(pin) }
        if selectedCity?.id == city.id { selectedCity = nil }
        modelContext.delete(city)
    }

    private func deleteCountry(_ country: Country) {
        let countryCities = cities.filter { $0.countryID == country.id }
        for city in countryCities {
            for pin in pins.filter({ $0.cityID == city.id }) { modelContext.delete(pin) }
            for pin in shopPins.filter({ $0.cityID == city.id }) { modelContext.delete(pin) }
            if selectedCity?.id == city.id { selectedCity = nil }
            modelContext.delete(city)
        }
        modelContext.delete(country)
    }
}

// MARK: - CountryHeaderView

struct CountryHeaderView: View {
    @Bindable var country: Country
    let cityCount: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    let onAddCity: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onToggle) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
            }
            .buttonStyle(.plain)
            Image(systemName: "globe")
                .foregroundStyle(.blue)
                .font(.caption)
            TextField("Country name", text: $country.name)
                .font(.subheadline.bold())
                .textFieldStyle(.plain)
            Spacer()
            Text("\(cityCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .clipShape(Capsule())
            Button(action: onAddCity) {
                Image(systemName: "plus.circle")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .help("Add city")
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete country and all its cities")
        }
        .padding(.vertical, 2)
    }
}

// MARK: - PendingPin

private struct PendingPin: Identifiable {
    let id = UUID()
    let location: CGPoint
}

// MARK: - CityMapView

struct CityMapView: View {
    @Bindable var city: City
    let stories: [Story]
    let pins: [StoryPin]
    let shopPins: [ShopPin]
    let shops: [Shop]
    let sectionState: SectionState

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(GalleryPresentationState.self) private var presentationState
    @State private var showMapImporter = false
    @State private var showSymbolImporter = false
    @State private var isPlacingPin = false
    @State private var isPlacingShopPin = false
    @State private var pendingPin: PendingPin?
    @State private var pendingShopPin: PendingPin?
    @State private var showPresentConfirm = false
    @State private var pinToDelete: StoryPin? = nil
    @State private var shopPinToDelete: ShopPin? = nil

    var cityShops: [Shop] { shops.filter { $0.cityID == city.id } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let symbolData = city.symbolImageData, let nsImage = NSImage(data: symbolData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)
                }
                TextField("City name", text: $city.name)
                    .font(.title2.bold())
                    .textFieldStyle(.plain)
                Spacer()
                if city.mapImageData != nil {
                    Toggle(isOn: $isPlacingPin) {
                        Label("Story", systemImage: "scroll.fill")
                    }
                    .toggleStyle(.button)
                    .tint(.indigo)
                    .onChange(of: isPlacingPin) { _, new in if new { isPlacingShopPin = false } }
                    .help("Place story pin")

                    Toggle(isOn: $isPlacingShopPin) {
                        Label("Shop", systemImage: "storefront.fill")
                    }
                    .toggleStyle(.button)
                    .tint(.orange)
                    .onChange(of: isPlacingShopPin) { _, new in if new { isPlacingPin = false } }
                    .help("Place shop pin")

                    Button {
                        showPresentConfirm = true
                    } label: {
                        Label("Present", systemImage: "display")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                }
                Button {
                    showSymbolImporter = true
                } label: {
                    Label(city.symbolImageData == nil ? "Import Symbol" : "Replace Symbol", systemImage: "seal")
                }
                .buttonStyle(.bordered)
                Button {
                    showMapImporter = true
                } label: {
                    Label(city.mapImageData == nil ? "Import Map" : "Replace Map", systemImage: "photo")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            HStack(spacing: 0) {
                if let data = city.mapImageData, let nsImage = NSImage(data: data) {
                    mapCanvas(nsImage: nsImage)
                } else {
                    ContentUnavailableView(
                        "No Map",
                        systemImage: "map",
                        description: Text("Import a map image to start placing pins.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Divider()

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Image(systemName: "text.alignleft")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Description")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)

                    Divider()

                    TextEditor(text: $city.cityDescription)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: 240)
            }
        }
        .fileImporter(isPresented: $showMapImporter, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result {
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url),
                   let nsImage = NSImage(data: data),
                   let png = nsImage.pngData {
                    city.mapImageData = png
                }
            }
        }
        .sheet(item: $pendingPin, onDismiss: { isPlacingPin = false }) { pending in
            PinStoryPickerSheet(
                stories: stories,
                pinnedStoryIDs: Set(pins.map { $0.storyID })
            ) { story in
                let pin = StoryPin(cityID: city.id, storyID: story.id, x: pending.location.x, y: pending.location.y)
                modelContext.insert(pin)
                if story.locationCityID == nil {
                    story.locationCityID = city.id
                }
            }
        }
        .sheet(item: $pendingShopPin, onDismiss: { isPlacingShopPin = false }) { pending in
            PinShopPickerSheet(
                shops: cityShops,
                pinnedShopIDs: Set(shopPins.map { $0.shopID })
            ) { shop in
                let pin = ShopPin(cityID: city.id, shopID: shop.id, x: pending.location.x, y: pending.location.y)
                modelContext.insert(pin)
            }
        }
        .alert("Remove Pin?", isPresented: Binding(get: { pinToDelete != nil }, set: { if !$0 { pinToDelete = nil } })) {
            Button("Remove", role: .destructive) {
                if let p = pinToDelete { modelContext.delete(p) }
                pinToDelete = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove this story pin from the map?")
        }
        .alert("Remove Shop Pin?", isPresented: Binding(get: { shopPinToDelete != nil }, set: { if !$0 { shopPinToDelete = nil } })) {
            Button("Remove", role: .destructive) {
                if let p = shopPinToDelete { modelContext.delete(p) }
                shopPinToDelete = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove this shop pin from the map?")
        }
        .alert("Present City Map?", isPresented: $showPresentConfirm) {
            Button("Present") {
                guard let data = city.mapImageData else { return }
                presentationState.items = [GalleryPresentationItem(title: city.name, data: data, symbolData: city.symbolImageData)]
                presentationState.currentIndex = 0
                openWindow(id: "gallery-presentation")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Opens the city map in full screen presentation mode.")
        }
        .fileImporter(isPresented: $showSymbolImporter, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result {
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url),
                   let nsImage = NSImage(data: data),
                   let png = nsImage.pngData {
                    city.symbolImageData = png
                }
            }
        }
    }

    @ViewBuilder
    private func mapCanvas(nsImage: NSImage) -> some View {
        Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                let norm = CGPoint(
                                    x: location.x / geo.size.width,
                                    y: location.y / geo.size.height
                                )
                                if isPlacingPin {
                                    pendingPin = PendingPin(location: norm)
                                } else if isPlacingShopPin {
                                    pendingShopPin = PendingPin(location: norm)
                                }
                            }

                        ForEach(pins) { pin in
                            let story = stories.first { $0.id == pin.storyID }
                            DraggablePinWrapper(
                                pin: pin,
                                geoSize: geo.size,
                                story: story,
                                allStories: stories,
                                shops: shops,
                                onRemovePin: { pinToDelete = pin },
                                onNavigateToStory: {
                                    if let story {
                                        sectionState.selectedStory = story
                                        sectionState.selectedSection = .stories
                                    }
                                }
                            )
                            .position(
                                x: pin.xPosition * geo.size.width,
                                y: pin.yPosition * geo.size.height
                            )
                            .allowsHitTesting(!isPlacingPin && !isPlacingShopPin)
                        }

                        ForEach(shopPins) { pin in
                            let shop = shops.first { $0.id == pin.shopID }
                            DraggableShopPinWrapper(
                                pin: pin,
                                geoSize: geo.size,
                                shop: shop,
                                onRemovePin: { shopPinToDelete = pin },
                                onNavigateToShop: {
                                    if let shop {
                                        sectionState.selectedShop = shop
                                        sectionState.selectedSection = .shops
                                    }
                                }
                            )
                            .position(
                                x: pin.xPosition * geo.size.width,
                                y: pin.yPosition * geo.size.height
                            )
                            .allowsHitTesting(!isPlacingPin && !isPlacingShopPin)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - DraggablePinWrapper

struct DraggablePinWrapper: View {
    @Bindable var pin: StoryPin
    let geoSize: CGSize
    let story: Story?
    let allStories: [Story]
    let shops: [Shop]
    let onRemovePin: () -> Void
    let onNavigateToStory: () -> Void

    @State private var showPopover = false
    @GestureState private var dragOffset: CGSize = .zero
    @State private var dragging = false

    var prerequisites: [Story] {
        guard let story else { return [] }
        return story.prerequisiteStoryIDs.compactMap { id in allStories.first { $0.id == id } }
    }

    var body: some View {
        MapPinMarker(
            story: story,
            isSelected: showPopover || dragging,
            linkedShops: story.map { s in shops.filter { $0.storyID == s.id } } ?? []
        )
            .offset(x: dragOffset.width, y: dragOffset.height)
            .gesture(
                DragGesture(minimumDistance: 4)
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onChanged { _ in dragging = true }
                    .onEnded { value in
                        let newX = min(max(pin.xPosition + value.translation.width / geoSize.width, 0), 1)
                        let newY = min(max(pin.yPosition + value.translation.height / geoSize.height, 0), 1)
                        pin.xPosition = newX
                        pin.yPosition = newY
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { dragging = false }
                    }
            )
            .onTapGesture {
                guard !dragging else { return }
                showPopover = true
            }
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                if let story {
                    PinDetailPopover(
                        story: story,
                        prerequisites: prerequisites,
                        onRemovePin: {
                            onRemovePin()
                            showPopover = false
                        },
                        onNavigateToStory: {
                            showPopover = false
                            onNavigateToStory()
                        }
                    )
                }
            }
    }
}

// MARK: - DraggableShopPinWrapper

struct DraggableShopPinWrapper: View {
    @Bindable var pin: ShopPin
    let geoSize: CGSize
    let shop: Shop?
    let onRemovePin: () -> Void
    let onNavigateToShop: () -> Void

    @State private var showPopover = false
    @GestureState private var dragOffset: CGSize = .zero
    @State private var dragging = false

    var body: some View {
        ShopPinMarker(shop: shop, isSelected: showPopover || dragging)
            .offset(x: dragOffset.width, y: dragOffset.height)
            .gesture(
                DragGesture(minimumDistance: 4)
                    .updating($dragOffset) { value, state, _ in state = value.translation }
                    .onChanged { _ in dragging = true }
                    .onEnded { value in
                        let newX = min(max(pin.xPosition + value.translation.width / geoSize.width, 0), 1)
                        let newY = min(max(pin.yPosition + value.translation.height / geoSize.height, 0), 1)
                        pin.xPosition = newX
                        pin.yPosition = newY
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { dragging = false }
                    }
            )
            .onTapGesture {
                guard !dragging else { return }
                showPopover = true
            }
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                ShopPinDetailPopover(
                    shop: shop,
                    onRemovePin: {
                        onRemovePin()
                        showPopover = false
                    },
                    onNavigateToShop: {
                        showPopover = false
                        onNavigateToShop()
                    }
                )
            }
    }
}

// MARK: - MapPinMarker

struct MapPinMarker: View {
    let story: Story?
    let isSelected: Bool
    var linkedShops: [Shop] = []

    var pinColor: Color { story?.status.color ?? .gray }
    var isMainQuest: Bool { story?.isMainQuest ?? true }

    var pinIcon: String {
        switch story?.status {
        case .completed: return "checkmark"
        case .failed:    return "xmark"
        default:         return isMainQuest ? "star.fill" : "diamond.fill"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let story {
                HStack(spacing: 3) {
                    if !isMainQuest {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Text(story.name)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(pinColor.opacity(isMainQuest ? 0.92 : 0.78))
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    isMainQuest ? Color.clear : Color.white.opacity(0.4),
                                    lineWidth: isMainQuest ? 0 : 1
                                )
                        )
                )

                CalloutTriangle()
                    .fill(pinColor.opacity(isMainQuest ? 0.92 : 0.78))
                    .frame(width: 10, height: 6)
            }

            ZStack {
                if isMainQuest {
                    Circle()
                        .fill(pinColor.gradient)
                        .frame(width: 22, height: 22)
                        .shadow(color: .black.opacity(0.3), radius: 3)
                        .overlay {
                            Circle().strokeBorder(
                                isSelected ? Color.white : Color.black.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                        }
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(pinColor.opacity(0.85))
                        .frame(width: 18, height: 18)
                        .rotationEffect(.degrees(45))
                        .shadow(color: .black.opacity(0.3), radius: 3)
                        .overlay {
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(
                                    isSelected ? Color.white : Color.white.opacity(0.3),
                                    lineWidth: isSelected ? 2 : 1
                                )
                                .rotationEffect(.degrees(45))
                        }
                }
                Image(systemName: pinIcon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 22, height: 22)
            .overlay(alignment: .bottomTrailing) {
                if !linkedShops.isEmpty {
                    let first = linkedShops[0]
                    ZStack {
                        Circle()
                            .fill(first.shopType.accentColor)
                            .frame(width: 18, height: 18)
                            .shadow(color: .black.opacity(0.4), radius: 2)
                        if linkedShops.count > 1 {
                            Text("\(linkedShops.count)")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: first.shopType.icon)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .offset(x: 6, y: 6)
                }
            }
        }
    }
}

// MARK: - ShopPinMarker

struct ShopPinMarker: View {
    let shop: Shop?
    let isSelected: Bool

    var pinColor: Color { shop?.shopType.accentColor ?? .orange }

    var body: some View {
        VStack(spacing: 0) {
            if let shop {
                Text(shop.name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(pinColor.opacity(0.92))
                            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    )

                CalloutTriangle()
                    .fill(pinColor.opacity(0.92))
                    .frame(width: 10, height: 6)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(pinColor.gradient)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.3), radius: 3)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(
                                isSelected ? Color.white : Color.black.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }
                Image(systemName: shop?.shopType.icon ?? "storefront.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 22, height: 22)
        }
    }
}

struct CalloutTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - PinDetailPopover

struct PinDetailPopover: View {
    @Bindable var story: Story
    let prerequisites: [Story]
    let onRemovePin: () -> Void
    let onNavigateToStory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !prerequisites.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Prerequisites")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 6)

                    ForEach(prerequisites) { prereq in
                        HStack(spacing: 8) {
                            Image(systemName: prereq.status.systemImage)
                                .foregroundStyle(prereq.status.color)
                                .font(.subheadline)
                            Text(prereq.name).font(.caption.bold())
                            Spacer()
                            Text(prereq.status.rawValue)
                                .font(.caption2)
                                .foregroundStyle(prereq.status.color)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(prereq.status.color.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 14).padding(.vertical, 5)
                    }
                }
                .background(Color.secondary.opacity(0.08))

                Divider()
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(story.name).font(.headline)
                        Text("Level \(story.level)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: Binding(get: { story.status }, set: { story.status = $0 })) {
                        ForEach(StoryStatus.allCases) { s in
                            Image(systemName: s.systemImage).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 96)
                    .labelsHidden()
                }

                if !story.storyDescription.isEmpty {
                    Text(story.storyDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(5)
                }

                if !story.npcEntries.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill").font(.caption2).foregroundStyle(.teal)
                        Text(story.npcEntries.map { $0.npcName }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Divider()

                Button(action: onNavigateToStory) {
                    Label("Open in Stories", systemImage: "scroll.fill")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.indigo)

                Button(role: .destructive, action: onRemovePin) {
                    Label("Remove Pin", systemImage: "mappin.slash")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
            .padding(14)
        }
        .frame(width: 300)
    }
}

// MARK: - ShopPinDetailPopover

struct ShopPinDetailPopover: View {
    let shop: Shop?
    let onRemovePin: () -> Void
    let onNavigateToShop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if let shop {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(shop.shopType.accentColor.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: shop.shopType.icon)
                            .font(.callout.bold())
                            .foregroundStyle(shop.shopType.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shop.name).font(.headline)
                        Text(shop.shopType.rawValue).font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Unknown Shop").font(.headline).foregroundStyle(.secondary)
                }
                Spacer()
                if let badge = shop?.questType.badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background((shop?.questType.color ?? .clear).opacity(0.2))
                        .foregroundStyle(shop?.questType.color ?? .clear)
                        .clipShape(Capsule())
                }
            }

            if let shop, !shop.ownerName.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill").font(.caption2).foregroundStyle(.secondary)
                    Text(shop.ownerName).font(.caption).foregroundStyle(.secondary)
                }
            }

            if let shop, !shop.shopDescription.isEmpty {
                Text(shop.shopDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Divider()

            Button(action: onNavigateToShop) {
                Label("Open in Shops", systemImage: "storefront.fill")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.orange)

            Button(role: .destructive, action: onRemovePin) {
                Label("Remove Pin", systemImage: "mappin.slash")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .padding(14)
        .frame(width: 280)
    }
}

// MARK: - PinStoryPickerSheet

struct PinStoryPickerSheet: View {
    let stories: [Story]
    let pinnedStoryIDs: Set<UUID>
    let onSelect: (Story) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var available: [Story] {
        let unpinned = stories.filter { !pinnedStoryIDs.contains($0.id) }
        if search.isEmpty { return unpinned }
        return unpinned.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pin Story").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.borderless)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            Divider()

            TextField("Search stories...", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16).padding(.vertical, 10)

            Divider()

            List {
                ForEach(available) { story in
                    Button {
                        onSelect(story)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(story.name).font(.subheadline)
                                Text("Level \(story.level)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: story.status.systemImage)
                                .foregroundStyle(story.status.color).font(.caption)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if available.isEmpty {
                    Text(stories.isEmpty ? "No stories yet" : "All stories are already pinned")
                        .foregroundStyle(.secondary).font(.callout)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
            }
        }
        .frame(width: 360, height: 420)
    }
}

// MARK: - PinShopPickerSheet

struct PinShopPickerSheet: View {
    let shops: [Shop]
    let pinnedShopIDs: Set<UUID>
    let onSelect: (Shop) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var available: [Shop] {
        let unpinned = shops.filter { !pinnedShopIDs.contains($0.id) }
        if search.isEmpty { return unpinned }
        return unpinned.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pin Shop").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.borderless)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            Divider()

            TextField("Search shops...", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16).padding(.vertical, 10)

            Divider()

            List {
                ForEach(available) { shop in
                    Button {
                        onSelect(shop)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(shop.shopType.accentColor.opacity(0.15))
                                    .frame(width: 30, height: 30)
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
                if available.isEmpty {
                    Text(shops.isEmpty ? "No shops in this city yet" : "All shops are already pinned")
                        .foregroundStyle(.secondary).font(.callout)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
            }
        }
        .frame(width: 360, height: 380)
    }
}

// MARK: - Add Sheets

struct AddCountrySheet: View {
    let campaignID: UUID
    let sortOrder: Int

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("New Country").font(.headline)
            TextField("Country name", text: $name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add") {
                    let country = Country(
                        name: name.isEmpty ? "New Country" : name,
                        campaignID: campaignID,
                        sortOrder: sortOrder
                    )
                    modelContext.insert(country)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}

struct AddCitySheet: View {
    let campaignID: UUID
    let countryID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("New City").font(.headline)
            TextField("City name", text: $name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add") {
                    let city = City(
                        name: name.isEmpty ? "New City" : name,
                        campaignID: campaignID,
                        countryID: countryID
                    )
                    modelContext.insert(city)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}

// MARK: - NSImage extension

private extension NSImage {
    var pngData: Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
