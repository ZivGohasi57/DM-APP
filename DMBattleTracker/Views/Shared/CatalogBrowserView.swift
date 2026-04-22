import SwiftUI
import SwiftData

struct CatalogBrowserView: View {
    let campaignID: UUID
    var defaultTypes: [CatalogItemType]
    var onAdd: (CatalogItem) -> Void
    let existingSlugs: Set<String>

    @StateObject private var catalog = CatalogService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allCustomItems: [CustomCatalogItem]
    @Query private var allWishlistItems: [PCWishlistItem]
    @Query private var allPCs: [PlayerCharacter]
    @Query private var allShops: [Shop]
    @Query private var allStories: [Story]

    @State private var selectedType: CatalogItemType?
    @State private var search = ""
    @State private var filterRarity: CatalogItemRarity? = nil
    @State private var filterSpellLevel: Int? = nil
    @State private var addedSlugs: Set<String> = []
    @State private var itemToDetail: CatalogItem? = nil
    @State private var showCustomEditor = false
    @State private var customItemToEdit: CustomCatalogItem? = nil
    @State private var showWishlists = false

    init(
        campaignID: UUID,
        defaultTypes: [CatalogItemType] = CatalogItemType.allCases,
        existingSlugs: Set<String> = [],
        onAdd: @escaping (CatalogItem) -> Void
    ) {
        self.campaignID = campaignID
        self.defaultTypes = defaultTypes
        self.existingSlugs = existingSlugs
        self.onAdd = onAdd
        _selectedType = State(initialValue: nil)
        let cid = campaignID
        _allCustomItems = Query(filter: #Predicate<CustomCatalogItem> { $0.campaignID == cid })
        _allWishlistItems = Query(filter: #Predicate<PCWishlistItem> { $0.campaignID == cid })
        _allPCs = Query(filter: #Predicate<PlayerCharacter> { $0.campaignID == cid }, sort: [SortDescriptor(\PlayerCharacter.name)])
        _allShops = Query(filter: #Predicate<Shop> { $0.campaignID == cid })
        _allStories = Query(filter: #Predicate<Story> { $0.campaignID == cid })
    }

    var activeTypes: [CatalogItemType] {
        selectedType.map { [$0] } ?? defaultTypes
    }

    var displayedItems: [CatalogItem] {
        let catalogItems = activeTypes.flatMap { catalog.items(type: $0, search: search, rarity: filterRarity) }
        let customItems = allCustomItems
            .filter { activeTypes.contains($0.itemType) }
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            .filter { filterRarity == nil || $0.rarity == filterRarity }
            .map { $0.toCatalogItem() }
        var combined = (customItems + catalogItems).sorted { $0.name < $1.name }
        if selectedType == .spell, let lvl = filterSpellLevel {
            if lvl == 0 {
                combined = combined.filter { $0.level == "0" || $0.level?.lowercased() == "cantrip" }
            } else {
                combined = combined.filter { $0.level == String(lvl) }
            }
        }
        return combined
    }

    var allWishlistSlugs: Set<String> {
        Set(allWishlistItems.map { $0.slug })
    }

    private func isAdded(_ slug: String) -> Bool {
        addedSlugs.contains(slug) || existingSlugs.contains(slug)
    }

    var body: some View {
        HStack(spacing: 0) {
            catalogPanel

            if showWishlists && !allPCs.isEmpty {
                Divider()
                wishlistPanel
            }
        }
        .frame(width: showWishlists && !allPCs.isEmpty ? 1020 : 560, height: 600)
        .animation(.easeInOut(duration: 0.2), value: showWishlists)
        .task { await catalog.load() }
        .sheet(item: $itemToDetail) { item in
            CatalogItemDetailView(item: item)
        }
        .sheet(isPresented: $showCustomEditor) {
            CustomItemEditorSheet(
                campaignID: campaignID,
                editingItem: customItemToEdit
            )
        }
    }

    private var catalogPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Catalog").font(.headline)
                Spacer()
                if !addedSlugs.isEmpty {
                    Text("\(addedSlugs.count) added")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !allPCs.isEmpty {
                    Button {
                        showWishlists.toggle()
                    } label: {
                        Label("Wishlists", systemImage: showWishlists ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundStyle(showWishlists ? Color.pink : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    Divider().frame(height: 20)
                }
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent).controlSize(.small)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button {
                        selectedType = nil
                        search = ""
                        filterRarity = nil
                        filterSpellLevel = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.grid.2x2").font(.caption)
                            Text("All").font(.caption.bold())
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(selectedType == nil ? Color.primary : Color.secondary.opacity(0.12))
                        .foregroundStyle(selectedType == nil ? Color(nsColor: .windowBackgroundColor) : Color.secondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    ForEach(CatalogItemType.allCases, id: \.self) { type in
                        Button {
                            selectedType = type
                            search = ""
                            filterRarity = nil
                            filterSpellLevel = nil
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: type.icon).font(.caption)
                                Text(type.rawValue).font(.caption.bold())
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(selectedType == type ? type.accentColor : Color.secondary.opacity(0.12))
                            .foregroundStyle(selectedType == type ? .white : .secondary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)

            Divider()

            if selectedType == .spell {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        Button { filterSpellLevel = nil } label: {
                            Text("All Levels").font(.caption2)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(filterSpellLevel == nil ? Color.teal : Color.secondary.opacity(0.12))
                                .foregroundStyle(filterSpellLevel == nil ? .white : .secondary)
                                .clipShape(Capsule())
                        }.buttonStyle(.plain)

                        Button { filterSpellLevel = 0 } label: {
                            Text("Cantrip").font(.caption2)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(filterSpellLevel == 0 ? Color.teal : Color.secondary.opacity(0.12))
                                .foregroundStyle(filterSpellLevel == 0 ? .white : .secondary)
                                .clipShape(Capsule())
                        }.buttonStyle(.plain)

                        ForEach(1...9, id: \.self) { lvl in
                            Button { filterSpellLevel = lvl } label: {
                                Text("Level \(lvl)").font(.caption2)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(filterSpellLevel == lvl ? Color.teal : Color.secondary.opacity(0.12))
                                    .foregroundStyle(filterSpellLevel == lvl ? .white : .secondary)
                                    .clipShape(Capsule())
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 6)

                Divider()
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.caption)
                TextField("Search \(selectedType?.rawValue ?? "all items")…", text: $search)
                    .textFieldStyle(.plain).font(.callout)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                if selectedType == .magicItem || selectedType == nil {
                    Menu {
                        Button("All Rarities") { filterRarity = nil }
                        Divider()
                        ForEach(CatalogItemRarity.allCases.filter { $0 != .varies && $0 != .unknown }, id: \.self) { r in
                            Button {
                                filterRarity = (filterRarity == r) ? nil : r
                            } label: {
                                Label(r.rawValue, systemImage: filterRarity == r ? "checkmark" : "circle")
                            }
                        }
                    } label: {
                        Image(systemName: filterRarity == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                            .foregroundStyle(filterRarity == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.accentColor))
                            .font(.caption)
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                }
                Divider().frame(height: 14)
                Button {
                    customItemToEdit = nil
                    showCustomEditor = true
                } label: {
                    Label("New Custom", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.purple)
                .help("Create a custom item")
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider()

            if !catalog.isLoaded {
                ProgressView("Loading catalog…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(displayedItems) { item in
                        catalogRow(item)
                    }
                    if displayedItems.isEmpty {
                        Text("No items found")
                            .foregroundStyle(.secondary).font(.callout)
                            .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 20)
                    }
                }
            }
        }
        .frame(width: 560)
    }

    private var wishlistPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Wishlists").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 14)

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(allPCs) { pc in
                        let items = allWishlistItems
                            .filter { $0.pcID == pc.id && !$0.acquired }
                            .sorted { $0.priorityRaw < $1.priorityRaw }
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(pc.name)
                                    .font(.caption.bold()).foregroundStyle(.secondary)
                                    .padding(.horizontal, 12)
                                ForEach(items) { entry in
                                    let shopCount = allShops.filter { shop in
                                        shop.inventory.contains(where: { $0.slug == entry.slug && $0.inStock })
                                    }.count
                                    let storyCount = allStories.filter { story in
                                        story.linkedItems.contains(where: { $0.slug == entry.slug })
                                    }.count
                                    let isAssigned = shopCount > 0 || storyCount > 0
                                    let rarity = rarityForSlug(entry.slug, type: entry.itemType)
                                    let alreadyAdded = isAdded(entry.slug)
                                    HStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(entry.itemType.accentColor.opacity(0.15))
                                                .frame(width: 18, height: 18)
                                            Image(systemName: entry.itemType.icon)
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundStyle(entry.itemType.accentColor)
                                        }
                                        Text(entry.name)
                                            .font(.caption)
                                            .foregroundStyle(isAssigned ? .primary : .secondary)
                                            .fontWeight(isAssigned ? .semibold : .regular)
                                        Spacer()
                                        if let rarity, rarity != .unknown {
                                            Text(rarity.rawValue)
                                                .font(.system(size: 9)).foregroundStyle(rarity.color)
                                                .padding(.horizontal, 4).padding(.vertical, 1)
                                                .background(rarity.color.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                        HStack(spacing: 4) {
                                            HStack(spacing: 2) {
                                                Image(systemName: shopCount > 0 ? "storefront.fill" : "storefront")
                                                    .font(.system(size: 9))
                                                    .foregroundStyle(shopCount > 0 ? Color.green : Color.secondary)
                                                Text("\(shopCount)")
                                                    .font(.system(size: 9).bold())
                                                    .foregroundStyle(shopCount > 0 ? Color.green : Color.secondary)
                                            }
                                            HStack(spacing: 2) {
                                                Image(systemName: storyCount > 0 ? "scroll.fill" : "scroll")
                                                    .font(.system(size: 9))
                                                    .foregroundStyle(storyCount > 0 ? Color.indigo : Color.secondary)
                                                Text("\(storyCount)")
                                                    .font(.system(size: 9).bold())
                                                    .foregroundStyle(storyCount > 0 ? Color.indigo : Color.secondary)
                                            }
                                        }
                                        Button {
                                            if let item = catalogItemForSlug(entry.slug, type: entry.itemType) {
                                                onAdd(item)
                                                addedSlugs.insert(entry.slug)
                                            }
                                        } label: {
                                            Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                                                .foregroundStyle(alreadyAdded ? Color.green : Color.blue)
                                                .font(.system(size: 16))
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(alreadyAdded)
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 3)
                                    .background(isAssigned ? Color.green.opacity(0.06) : Color.clear)
                                }
                            }
                            .padding(.vertical, 8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    if allPCs.allSatisfy({ pc in allWishlistItems.filter { $0.pcID == pc.id && !$0.acquired }.isEmpty }) {
                        Text("No active wishlists")
                            .font(.caption).foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 20)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 420)
    }

    @ViewBuilder
    private func catalogRow(_ item: CatalogItem) -> some View {
        let wishlistedByPCIDs = Set(allWishlistItems.filter { $0.slug == item.slug }.map { $0.pcID })
        let wishlistedPCs = allPCs.filter { wishlistedByPCIDs.contains($0.id) }
        let added = isAdded(item.slug)

        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(item.type.accentColor.opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: item.type.icon)
                    .font(.caption.bold())
                    .foregroundStyle(item.type.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name).font(.subheadline)
                    if item.type == .magicItem && item.rarity != .unknown {
                        Text(item.rarity.rawValue)
                            .font(.caption2).foregroundStyle(item.rarity.color)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(item.rarity.color.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    if item.type == .spell, let level = item.level {
                        Text(level == "0" ? "Cantrip" : "Lv \(level)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if item.slug.hasPrefix("custom-") {
                        Text("Custom")
                            .font(.caption2.bold())
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.purple.opacity(0.12))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                    if !wishlistedPCs.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill").font(.system(size: 8)).foregroundStyle(.pink)
                            Text(wishlistedPCs.map { $0.name }.joined(separator: ", "))
                                .font(.caption2).foregroundStyle(.pink)
                        }
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.pink.opacity(0.08))
                        .clipShape(Capsule())
                    }
                }
                HStack(spacing: 6) {
                    Text(item.category).font(.caption2).foregroundStyle(.tertiary)
                    if item.cost != "—" && !item.cost.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(item.cost).font(.caption2).foregroundStyle(.secondary)
                    }
                    if item.type == .weapon, let dice = item.damageDice {
                        Text("·").foregroundStyle(.tertiary)
                        Text(dice).font(.caption2).foregroundStyle(.secondary)
                    }
                    if item.type == .armor, let ac = item.acString {
                        Text("·").foregroundStyle(.tertiary)
                        Text(ac).font(.caption2).foregroundStyle(.secondary)
                    }
                    if item.attunement {
                        Text("·").foregroundStyle(.tertiary)
                        Text("attunement").font(.caption2).foregroundStyle(.purple)
                    }
                    if item.concentration {
                        Text("·").foregroundStyle(.tertiary)
                        Text("conc.").font(.caption2).foregroundStyle(.teal)
                    }
                }
            }

            Spacer()

            Button {
                itemToDetail = item
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .help("View details")

            if item.slug.hasPrefix("custom-") {
                Button {
                    customItemToEdit = CustomCatalogItem.fromSlug(item.slug, in: allCustomItems)
                    showCustomEditor = true
                } label: {
                    Image(systemName: "pencil.circle")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .help("Edit custom item")

                Button {
                    if let customItem = CustomCatalogItem.fromSlug(item.slug, in: allCustomItems) {
                        modelContext.delete(customItem)
                    }
                } label: {
                    Image(systemName: "trash.circle")
                        .foregroundStyle(.red.opacity(0.7))
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .help("Delete custom item")
            }

            Button {
                onAdd(item)
                addedSlugs.insert(item.slug)
            } label: {
                Image(systemName: added ? "checkmark.circle.fill" : "plus.circle.fill")
                    .foregroundStyle(added ? .green : .blue)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(added)
        }
        .padding(.vertical, 2)
    }

    private func catalogItemForSlug(_ slug: String, type: CatalogItemType) -> CatalogItem? {
        if slug.hasPrefix("custom-") {
            return allCustomItems.first(where: { "custom-\($0.id.uuidString)" == slug })?.toCatalogItem()
        }
        return catalog.items(type: type, search: "", rarity: nil).first(where: { $0.slug == slug })
    }

    private func rarityForSlug(_ slug: String, type: CatalogItemType) -> CatalogItemRarity? {
        if slug.hasPrefix("custom-") {
            return allCustomItems.first(where: { "custom-\($0.id.uuidString)" == slug })?.rarity
        }
        return catalog.items(type: type, search: "", rarity: nil).first(where: { $0.slug == slug })?.rarity
    }
}

// MARK: - CatalogView

struct CatalogView: View {
    let campaign: Campaign

    @StateObject private var catalog = CatalogService.shared
    @Environment(\.modelContext) private var modelContext
    @Query private var allCustomItems: [CustomCatalogItem]

    @State private var selectedItem: CatalogItem? = nil
    @State private var selectedType: CatalogItemType? = nil
    @State private var search = ""
    @State private var filterRarity: CatalogItemRarity? = nil
    @State private var filterSpellLevel: Int? = nil
    @State private var showCustomEditor = false
    @State private var customItemToEdit: CustomCatalogItem? = nil
    @State private var deleteTarget: CustomCatalogItem? = nil
    @State private var showDeleteConfirm = false

    init(campaign: Campaign) {
        self.campaign = campaign
        let cid = campaign.id
        _allCustomItems = Query(
            filter: #Predicate<CustomCatalogItem> { $0.campaignID == cid },
            sort: [SortDescriptor(\CustomCatalogItem.name)]
        )
    }

    var campaignCustomItems: [CustomCatalogItem] {
        allCustomItems.filter { $0.campaignID == campaign.id }
    }

    var displayedItems: [CatalogItem] {
        let types: [CatalogItemType] = selectedType.map { [$0] } ?? CatalogItemType.allCases
        let catalogItems = types.flatMap { catalog.items(type: $0, search: search, rarity: filterRarity) }
        let customItems = campaignCustomItems
            .filter { types.contains($0.itemType) }
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            .filter { filterRarity == nil || $0.rarity == filterRarity }
            .map { $0.toCatalogItem() }
        var combined = (customItems + catalogItems).sorted { $0.name < $1.name }
        if selectedType == .spell, let lvl = filterSpellLevel {
            combined = combined.filter { spellMatchesLevel($0, lvl: lvl) }
        }
        return combined
    }

    private func spellMatchesLevel(_ item: CatalogItem, lvl: Int) -> Bool {
        let level = item.level?.lowercased() ?? ""
        if lvl == 0 { return level == "cantrip" || level == "0" }
        return level.hasPrefix(String(lvl))
    }

    private func spellLevelLabel(_ item: CatalogItem) -> String? {
        guard let lvl = item.level else { return nil }
        if lvl.lowercased() == "cantrip" || lvl == "0" { return "Cantrip" }
        return lvl.capitalized
    }

    var body: some View {
        HStack(spacing: 0) {
            catalogListPanel
            Divider()
            catalogDetailPanel
        }
        .navigationTitle("Catalog")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    customItemToEdit = nil
                    showCustomEditor = true
                } label: {
                    Label("New Custom Item", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showCustomEditor) {
            CustomItemEditorSheet(campaignID: campaign.id, editingItem: customItemToEdit)
        }
        .alert("Delete Item?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let item = deleteTarget {
                    if selectedItem?.slug == "custom-\(item.id.uuidString)" { selectedItem = nil }
                    modelContext.delete(item)
                    deleteTarget = nil
                }
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            if let item = deleteTarget { Text("Delete '\(item.name)'? This cannot be undone.") }
        }
        .task { await catalog.load() }
    }

    private var catalogListPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach([CatalogItemType?.none] + CatalogItemType.allCases.map(Optional.some), id: \.self) { type in
                    Button {
                        selectedType = type; search = ""; filterRarity = nil; filterSpellLevel = nil
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: type?.icon ?? "square.grid.2x2")
                                .font(.system(size: 13, weight: .medium))
                            Text(type?.rawValue ?? "All")
                                .font(.system(size: 9, weight: .semibold))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedType == type
                            ? (type?.accentColor ?? Color.indigo).opacity(0.25)
                            : Color.clear)
                        .foregroundStyle(selectedType == type
                            ? (type?.accentColor ?? Color.indigo)
                            : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    if type != CatalogItemType.allCases.last {
                        Divider().frame(height: 28)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if selectedType == .spell {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        catalogSpellPill(nil, label: "All")
                        catalogSpellPill(0, label: "Cantrip")
                        ForEach(1...9, id: \.self) { lvl in catalogSpellPill(lvl, label: "Lv \(lvl)") }
                    }
                    .padding(.horizontal, 10)
                }
                .padding(.vertical, 6)
                Divider()
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.caption)
                TextField("Search \(selectedType?.rawValue ?? "all items")…", text: $search)
                    .textFieldStyle(.plain).font(.callout)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).font(.caption)
                    }.buttonStyle(.plain)
                }
                if selectedType == .magicItem || selectedType == nil {
                    Menu {
                        Button("All Rarities") { filterRarity = nil }
                        Divider()
                        ForEach(CatalogItemRarity.allCases, id: \.self) { r in
                            Button { filterRarity = filterRarity == r ? nil : r } label: {
                                Label(r.rawValue, systemImage: filterRarity == r ? "checkmark" : "circle")
                            }
                        }
                    } label: {
                        Image(systemName: filterRarity == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                            .foregroundStyle(filterRarity == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.accentColor))
                            .font(.caption)
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider()

            if !catalog.isLoaded {
                ProgressView("Loading catalog…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayedItems, id: \.slug) { item in
                            catalogItemRow(item)
                                .background(selectedItem?.slug == item.slug
                                    ? Color.accentColor.opacity(0.18)
                                    : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .contentShape(Rectangle())
                                .onTapGesture { selectedItem = item }
                            if item.slug != displayedItems.last?.slug {
                                Divider().padding(.leading, 46)
                            }
                        }
                    }
                    .padding(.horizontal, 6).padding(.vertical, 4)
                }

                Divider()
                Text("\(displayedItems.count) items")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .padding(.horizontal, 12).padding(.vertical, 5)
            }
        }
        .frame(minWidth: 300, maxWidth: 360)
    }

    @ViewBuilder
    private var catalogDetailPanel: some View {
        if let item = selectedItem {
            CatalogDetailPanel(
                item: item,
                customItem: campaignCustomItems.first(where: { "custom-\($0.id.uuidString)" == item.slug }),
                onEdit: { ci in customItemToEdit = ci; showCustomEditor = true },
                onDelete: { ci in deleteTarget = ci; showDeleteConfirm = true },
                onHide: { slug in catalog.hideItem(slug: slug); selectedItem = nil }
            )
        } else {
            ContentUnavailableView("Select an Item", systemImage: "books.vertical",
                description: Text("Choose an item from the list to view its details."))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func catalogItemRow(_ item: CatalogItem) -> some View {
        let isCustom = item.slug.hasPrefix("custom-")
        let ci = isCustom ? campaignCustomItems.first(where: { "custom-\($0.id.uuidString)" == item.slug }) : nil
        let isSelected = selectedItem?.slug == item.slug

        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(item.type.accentColor.opacity(isSelected ? 0.35 : 0.18))
                    .frame(width: 30, height: 30)
                Image(systemName: item.type.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(item.type.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .primary : .primary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if item.type == .magicItem && item.rarity != .unknown {
                        Text(item.rarity.rawValue).font(.caption2).foregroundStyle(item.rarity.color)
                    } else if item.type == .spell, let lbl = spellLevelLabel(item) {
                        Text(lbl).font(.caption2).foregroundStyle(.secondary)
                    } else if item.type == .weapon, let dice = item.damageDice {
                        Text(dice).font(.caption2).foregroundStyle(.secondary)
                    } else if item.type == .armor, let ac = item.acString {
                        Text(ac).font(.caption2).foregroundStyle(.secondary)
                    }
                    if !item.cost.isEmpty && item.cost != "—" {
                        Text("·").font(.caption2).foregroundStyle(.tertiary)
                        Text(item.cost).font(.caption2).foregroundStyle(.tertiary)
                    }
                    if isCustom {
                        Text("Custom").font(.system(size: 8).bold())
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.purple.opacity(0.15)).foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
            if let ci {
                HStack(spacing: 2) {
                    Button { customItemToEdit = ci; showCustomEditor = true } label: {
                        Image(systemName: "pencil.circle").font(.caption).foregroundStyle(.secondary)
                    }.buttonStyle(.plain).help("Edit")
                    Button { deleteTarget = ci; showDeleteConfirm = true } label: {
                        Image(systemName: "trash.circle").font(.caption).foregroundStyle(.red.opacity(0.6))
                    }.buttonStyle(.plain).help("Delete")
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
    }

    @ViewBuilder
    private func catalogSpellPill(_ level: Int?, label: String) -> some View {
        Button { filterSpellLevel = level } label: {
            Text(label).font(.caption2)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(filterSpellLevel == level ? Color.teal : Color.secondary.opacity(0.12))
                .foregroundStyle(filterSpellLevel == level ? .white : .secondary)
                .clipShape(Capsule())
        }.buttonStyle(.plain)
    }
}

// MARK: - CatalogItemBody

struct CatalogItemBody: View {
    let item: CatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(item.name)
                .font(.largeTitle.bold())

            if !item.source.isEmpty {
                sourcePill(item.source)
            }

            typeSection

            Divider()

            statBoxes

            if let mat = item.material, !mat.isEmpty {
                Divider()
                sectionHeader("MATERIAL COMPONENT")
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(red: 0.75, green: 0.65, blue: 0.2))
                        .frame(width: 3)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    Text(mat)
                        .font(.callout.italic())
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.07)))
            }

            if !item.desc.isEmpty || item.higherLevel != nil {
                Divider()
                let isSpell = item.type == .spell
                sectionHeader(isSpell ? "DESCRIPTION" : "PROPERTIES")
                if !item.desc.isEmpty {
                    Text(item.desc)
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let hl = item.higherLevel {
                    sectionHeader("AT HIGHER LEVELS")
                        .padding(.top, 8)
                    Text(hl).font(.callout).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func sourcePill(_ source: String) -> some View {
        Text(source.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.white.opacity(0.08))
            .foregroundStyle(.secondary)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.1)))
    }

    @ViewBuilder
    private var typeSection: some View {
        switch item.type {
        case .spell:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    let lvlStr: String = {
                        guard let v = item.level else { return "" }
                        return v.lowercased() == "cantrip" || v == "0" ? "Cantrip" : v.capitalized
                    }()
                    let school = item.school ?? ""
                    Text(school.isEmpty ? lvlStr : "\(lvlStr) · \(school)")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Image(systemName: "questionmark.circle")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                if item.concentration || item.ritual {
                    HStack(spacing: 6) {
                        if item.concentration { pill("Concentration", .teal) }
                        if item.ritual { pill("Ritual", .purple) }
                    }
                }
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                Text(item.category)
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    if item.rarity != .unknown && item.rarity != .varies {
                        rarityBadge(item.rarity)
                    }
                    if item.attunement {
                        pill("Requires Attunement", Color(red: 0.75, green: 0.65, blue: 0.2))
                    }
                    if item.slug.hasPrefix("custom-") {
                        pill("Custom", .purple)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statBoxes: some View {
        let cols = [GridItem(.adaptive(minimum: 130))]
        switch item.type {
        case .spell:
            LazyVGrid(columns: cols, spacing: 8) {
                if let v = item.castingTime { statBox("CASTING TIME", v) }
                if let v = item.spellRange { statBox("RANGE", v) }
                if let v = item.components { statBox("COMPONENTS", v) }
                if let v = item.duration { statBox("DURATION", v) }
                if let v = item.level {
                    let d = v.lowercased() == "cantrip" || v == "0" ? "Cantrip" : v.capitalized
                    statBox("LEVEL", d)
                }
                if let v = item.school { statBox("SCHOOL", v.capitalized) }
                if !item.source.isEmpty { statBox("SOURCE", item.source) }
                if let v = item.dndClass, !v.isEmpty { statBox("CLASSES", v) }
            }
        case .weapon:
            LazyVGrid(columns: cols, spacing: 8) {
                if !item.cost.isEmpty && item.cost != "—" { statBox("COST", item.cost) }
                if let v = item.weight, !v.isEmpty, v != "0" { statBox("WEIGHT", "\(v) lbs") }
                if let v = item.damageDice { statBox("DAMAGE", v) }
                if !item.source.isEmpty { statBox("SOURCE", item.source) }
            }
        case .armor:
            LazyVGrid(columns: cols, spacing: 8) {
                if !item.cost.isEmpty && item.cost != "—" { statBox("COST", item.cost) }
                if let v = item.weight, !v.isEmpty, v != "0" { statBox("WEIGHT", "\(v) lbs") }
                if let v = item.acString { statBox("AC", v) }
                if !item.source.isEmpty { statBox("SOURCE", item.source) }
            }
        case .magicItem:
            LazyVGrid(columns: cols, spacing: 8) {
                if !item.cost.isEmpty && item.cost != "—" { statBox("COST", item.cost) }
                if let v = item.weight, !v.isEmpty, v != "0" { statBox("WEIGHT", "\(v) lbs") }
                if !item.source.isEmpty { statBox("SOURCE", item.source) }
            }
        }
    }

    private func statBox(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            Text(value)
                .font(.callout.bold())
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.07)))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.85))
            .tracking(0.8)
    }

    private func rarityBadge(_ rarity: CatalogItemRarity) -> some View {
        HStack(spacing: 4) {
            Text(rarity.rawValue)
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 10))
        }
        .font(.caption.bold())
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(rarity.color.opacity(0.15))
        .foregroundStyle(rarity.color)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(rarity.color.opacity(0.25)))
    }

    private func pill(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.25)))
    }
}

// MARK: - CatalogDetailPanel

struct CatalogDetailPanel: View {
    let item: CatalogItem
    let customItem: CustomCatalogItem?
    let onEdit: (CustomCatalogItem) -> Void
    let onDelete: (CustomCatalogItem) -> Void
    let onHide: (String) -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    if let ci = customItem {
                        Button { onEdit(ci) } label: { Label("Edit", systemImage: "pencil") }
                            .buttonStyle(.bordered)
                        Button { onDelete(ci) } label: { Label("Delete", systemImage: "trash") }
                            .buttonStyle(.bordered).foregroundStyle(.red)
                    } else {
                        Button { showDeleteConfirm = true } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.bordered).foregroundStyle(.red)
                    }
                }
                CatalogItemBody(item: item)
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog("Delete \"\(item.name)\"?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onHide(item.slug) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This item will be hidden from the catalog. This cannot be undone.")
        }
    }
}
