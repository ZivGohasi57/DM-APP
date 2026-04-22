import SwiftUI
import SwiftData

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
            combined = combined.filter {
                lvl == 0
                    ? ($0.level == "0" || $0.level?.lowercased() == "cantrip")
                    : $0.level == String(lvl)
            }
        }
        return combined
    }

    var body: some View {
        HStack(spacing: 0) {
            listPanel
            Divider()
            detailPanel
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
                    if selectedItem?.slug == "custom-\(item.id.uuidString)" {
                        selectedItem = nil
                    }
                    modelContext.delete(item)
                    deleteTarget = nil
                }
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            if let item = deleteTarget {
                Text("Delete '\(item.name)'? This cannot be undone.")
            }
        }
        .task { await catalog.load() }
    }

    private var listPanel: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    typeButton(nil, icon: "square.grid.2x2", label: "All")
                    ForEach(CatalogItemType.allCases, id: \.self) { type in
                        typeButton(type, icon: type.icon, label: type.rawValue)
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.vertical, 8)

            Divider()

            if selectedType == .spell {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        spellLevelPill(nil, label: "All")
                        spellLevelPill(0, label: "Cantrip")
                        ForEach(1...9, id: \.self) { lvl in
                            spellLevelPill(lvl, label: "Lv \(lvl)")
                        }
                    }
                    .padding(.horizontal, 12)
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
                        ForEach(CatalogItemRarity.allCases, id: \.self) { r in
                            Button {
                                filterRarity = filterRarity == r ? nil : r
                            } label: {
                                Label(r.rawValue, systemImage: filterRarity == r ? "checkmark" : "circle")
                            }
                        }
                    } label: {
                        Image(systemName: filterRarity == nil
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
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
                List(displayedItems, id: \.slug, selection: $selectedItem) { item in
                    itemRow(item)
                        .tag(item)
                }
                .listStyle(.sidebar)

                Text("\(displayedItems.count) items")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
            }
        }
        .frame(minWidth: 280, maxWidth: 340)
    }

    @ViewBuilder
    private var detailPanel: some View {
        if let item = selectedItem {
            CatalogDetailPanel(
                item: item,
                customItem: campaignCustomItems.first(where: { "custom-\($0.id.uuidString)" == item.slug }),
                onEdit: { ci in
                    customItemToEdit = ci
                    showCustomEditor = true
                },
                onDelete: { ci in
                    deleteTarget = ci
                    showDeleteConfirm = true
                }
            )
        } else {
            ContentUnavailableView(
                "Select an Item",
                systemImage: "books.vertical",
                description: Text("Choose an item from the list to view its details.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func itemRow(_ item: CatalogItem) -> some View {
        let isCustom = item.slug.hasPrefix("custom-")
        let customItem = isCustom ? campaignCustomItems.first(where: { "custom-\($0.id.uuidString)" == item.slug }) : nil

        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(item.type.accentColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: item.type.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(item.type.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(item.name).font(.subheadline).lineLimit(1)
                    if isCustom {
                        Text("Custom")
                            .font(.system(size: 8).bold())
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.purple.opacity(0.12))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 4) {
                    if item.type == .magicItem && item.rarity != .unknown {
                        Text(item.rarity.rawValue).font(.caption2).foregroundStyle(item.rarity.color)
                    } else if item.type == .spell, let lvl = item.level {
                        Text(lvl == "0" ? "Cantrip" : "Lv \(lvl)").font(.caption2).foregroundStyle(.secondary)
                    } else if item.type == .weapon, let dice = item.damageDice {
                        Text(dice).font(.caption2).foregroundStyle(.secondary)
                    } else if item.type == .armor, let ac = item.acString {
                        Text(ac).font(.caption2).foregroundStyle(.secondary)
                    }
                    if !item.cost.isEmpty && item.cost != "—" {
                        Text("·").font(.caption2).foregroundStyle(.tertiary)
                        Text(item.cost).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if isCustom, let ci = customItem {
                HStack(spacing: 4) {
                    Button {
                        customItemToEdit = ci
                        showCustomEditor = true
                    } label: {
                        Image(systemName: "pencil.circle").font(.caption).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain).help("Edit")

                    Button {
                        deleteTarget = ci
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash.circle").font(.caption).foregroundStyle(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain).help("Delete")
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func typeButton(_ type: CatalogItemType?, icon: String, label: String) -> some View {
        Button {
            selectedType = type
            search = ""
            filterRarity = nil
            filterSpellLevel = nil
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption.bold())
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(selectedType == type ? (type?.accentColor ?? Color.primary) : Color.secondary.opacity(0.12))
            .foregroundStyle(selectedType == type ? .white : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func spellLevelPill(_ level: Int?, label: String) -> some View {
        Button { filterSpellLevel = level } label: {
            Text(label).font(.caption2)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(filterSpellLevel == level ? Color.teal : Color.secondary.opacity(0.12))
                .foregroundStyle(filterSpellLevel == level ? .white : .secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail Panel

private struct CatalogDetailPanel: View {
    let item: CatalogItem
    let customItem: CustomCatalogItem?
    let onEdit: (CustomCatalogItem) -> Void
    let onDelete: (CustomCatalogItem) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                detailHeader
                statsSection
                if !item.desc.isEmpty { descriptionSection }
                if !item.source.isEmpty {
                    Text("Source: \(item.source)")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var detailHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.type.accentColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: item.type.icon)
                    .font(.title2.bold())
                    .foregroundStyle(item.type.accentColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.name).font(.title2.bold())
                    if item.slug.hasPrefix("custom-") {
                        Text("Custom")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 6) {
                    Text(item.type.rawValue).font(.subheadline).foregroundStyle(.secondary)
                    if item.type == .magicItem && item.rarity != .unknown {
                        Text("·").foregroundStyle(.secondary)
                        Text(item.rarity.rawValue).font(.caption.bold()).foregroundStyle(item.rarity.color)
                    }
                }
                Text(item.category).font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
            if let ci = customItem {
                HStack(spacing: 8) {
                    Button { onEdit(ci) } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)

                    Button { onDelete(ci) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
                }
            }
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        switch item.type {
        case .spell:     spellStats
        case .weapon:    weaponStats
        case .armor:     armorStats
        case .magicItem: magicItemStats
        }
    }

    private var spellStats: some View {
        GroupBox {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                if let v = item.level { statRow("Level", v == "0" ? "Cantrip" : "Level \(v)") }
                if let v = item.school { statRow("School", v) }
                if let v = item.castingTime { statRow("Casting Time", v) }
                if let v = item.spellRange { statRow("Range", v) }
                if let v = item.components { statRow("Components", v) }
                if let v = item.duration { statRow("Duration", v) }
                GridRow {
                    Text("Flags").font(.caption.bold()).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        if item.concentration { flagBadge("Concentration", .teal) }
                        if item.ritual { flagBadge("Ritual", .purple) }
                        if !item.concentration && !item.ritual {
                            Text("—").font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }
                if let v = item.dndClass { statRow("Classes", v) }
                if let v = item.material { statRow("Material", v) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var weaponStats: some View {
        GroupBox {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                if let v = item.damageDice {
                    GridRow {
                        Text("Damage").font(.caption.bold()).foregroundStyle(.secondary)
                        Text(v).font(.callout.bold()).foregroundStyle(.orange)
                    }
                }
                statRow("Cost", item.cost)
                if let v = item.weight { statRow("Weight", v) }
                if !item.desc.isEmpty { statRow("Properties", item.desc) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var armorStats: some View {
        GroupBox {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                if let v = item.acString {
                    GridRow {
                        Text("AC").font(.caption.bold()).foregroundStyle(.secondary)
                        Text(v).font(.callout.bold()).foregroundStyle(.blue)
                    }
                }
                statRow("Cost", item.cost)
                if let v = item.weight { statRow("Weight", v) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var magicItemStats: some View {
        GroupBox {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    Text("Rarity").font(.caption.bold()).foregroundStyle(.secondary)
                    Text(item.rarity.rawValue).font(.callout.bold()).foregroundStyle(item.rarity.color)
                }
                statRow("Cost", item.cost)
                if let v = item.weight { statRow("Weight", v) }
                if item.attunement {
                    GridRow {
                        Text("Attunement").font(.caption.bold()).foregroundStyle(.secondary)
                        flagBadge("Required", .purple)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var descriptionSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Label("Description", systemImage: "text.alignleft")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                Text(item.desc).font(.callout).textSelection(.enabled)
                if let hl = item.higherLevel {
                    Divider()
                    Text("At Higher Levels").font(.caption.bold()).foregroundStyle(.secondary)
                    Text(hl).font(.callout).textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func statRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).font(.caption.bold()).foregroundStyle(.secondary)
            Text(value).font(.callout)
        }
    }

    private func flagBadge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
