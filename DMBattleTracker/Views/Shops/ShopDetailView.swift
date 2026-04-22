import SwiftUI
import SwiftData

struct ShopDetailView: View {
    @Bindable var shop: Shop
    let cities: [City]
    let countries: [Country]
    let campaign: Campaign
    let sectionState: SectionState

    @StateObject private var catalog = CatalogService.shared
    @Query private var allCustomItems: [CustomCatalogItem]
    @Query private var allNPCs: [NPCTemplate]
    @Query private var allStories: [Story]
    @Query private var allPCs: [PlayerCharacter]
    @Query private var allWishlistItems: [PCWishlistItem]

    @State private var showCatalogBrowser = false
    @State private var showRandomizeConfirm = false
    @State private var showSellCatalog = false
    @State private var pendingSellItem: CatalogItem? = nil
    @State private var confirmSellItem: CatalogItem? = nil
    @State private var pendingBuyEntry: ShopInventoryEntry? = nil
    @State private var itemToDetail: CatalogItem? = nil
    @State private var showNPCPicker = false
    @State private var showCreateNPC = false
    @State private var showStoryPicker = false

    var campaignPCs: [PlayerCharacter] {
        allPCs.filter { $0.campaignID == campaign.id }.sorted { $0.name < $1.name }
    }

    var shopCity: City? { cities.first { $0.id == shop.cityID } }
    var shopCountry: Country? {
        guard let city = shopCity else { return nil }
        return countries.first { $0.id == city.countryID }
    }
    var linkedNPC: NPCTemplate? {
        guard let id = shop.ownerNPCID else { return nil }
        return allNPCs.first { $0.id == id }
    }
    var linkedStory: Story? {
        guard let id = shop.storyID else { return nil }
        return allStories.first { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                shopHeader
                ownerGroupBox
                linkedStoryGroupBox
                descriptionGroupBox
                financesGroupBox
                inventoryGroupBox
            }
            .padding(24)
        }
        .sheet(isPresented: $showCatalogBrowser) {
            CatalogBrowserView(
                campaignID: campaign.id,
                defaultTypes: shop.shopType.defaultCatalogTypes,
                existingSlugs: Set(shop.inventory.map { $0.slug })
            ) { item in
                var inv = shop.inventory
                guard !inv.contains(where: { $0.slug == item.slug }) else { return }
                inv.append(ShopInventoryEntry(from: item))
                shop.setInventory(inv)
            }
        }
        .sheet(isPresented: $showSellCatalog, onDismiss: {
            if let item = pendingSellItem {
                pendingSellItem = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    confirmSellItem = item
                }
            }
        }) {
            CatalogBrowserView(campaignID: campaign.id) { item in
                pendingSellItem = item
                showSellCatalog = false
            }
        }
        .sheet(item: $confirmSellItem) { item in
            SellPriceSheet(item: item, suggestedPrice: spellDefaultCost(for: item)) { buyPrice in
                var inv = shop.inventory
                if let idx = inv.firstIndex(where: { $0.slug == item.slug }) {
                    inv[idx].quantity += 1
                } else {
                    inv.append(ShopInventoryEntry(from: item))
                }
                shop.setInventory(inv)
                shop.totalEarned -= buyPrice
            }
        }
        .sheet(item: $pendingBuyEntry) { entry in
            BuyPCPickerSheet(
                entry: entry,
                suggestedPrice: priceGold(for: entry),
                suggestedPriceString: entry.customPrice != nil
                    ? "\(Int(entry.customPrice!)) gp"
                    : (entry.catalogCost.isEmpty || entry.catalogCost == "—" ? "" : entry.catalogCost),
                pcs: campaignPCs
            ) { pc, actualPrice in
                mutateEntry(id: entry.id) { e in if e.quantity > 0 { e.quantity -= 1 } }
                shop.totalEarned += actualPrice
                pc.gold -= Int(actualPrice)

                if entry.itemType != .spell {
                    let weight = parseWeight(catalogItem(for: entry)?.weight)
                    var inv = pc.inventory
                    if let idx = inv.firstIndex(where: { $0.name == entry.name }) {
                        inv[idx].quantity += 1
                    } else {
                        inv.append(InventoryItem(id: UUID(), name: entry.name, quantity: 1, weightPerUnit: weight))
                    }
                    pc.inventory = inv
                }

                if let wishlistItem = allWishlistItems.first(where: { $0.pcID == pc.id && $0.slug == entry.slug }) {
                    wishlistItem.acquired = true
                }
            }
        }
        .sheet(item: $itemToDetail) { item in
            CatalogItemDetailView(item: item)
        }
        .sheet(isPresented: $showNPCPicker) {
            ShopOwnerNPCPickerSheet(
                npcs: allNPCs.filter { $0.campaignID == campaign.id }
            ) { npc in
                shop.ownerNPCID = npc.id
                shop.ownerName = npc.name
            }
        }
        .sheet(isPresented: $showCreateNPC) {
            AddNPCSheet(campaignID: campaign.id) { npc in
                shop.ownerNPCID = npc.id
                shop.ownerName = npc.name
            }
        }
        .sheet(isPresented: $showStoryPicker) {
            ShopStoryPickerSheet(
                stories: allStories.filter { $0.campaignID == campaign.id }
            ) { story in
                shop.storyID = story.id
                shop.linkedStoryName = story.name
            }
        }
        .alert("Randomize Inventory?", isPresented: $showRandomizeConfirm) {
            Button("Randomize", role: .destructive) {
                ShopRandomizer.randomize(shop: shop, catalog: catalog)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will replace the current inventory with up to 10 randomly generated items based on the shop's type (\(shop.shopType.rawValue)) and quality (\(shop.quality.rawValue)).")
        }
        .task { await catalog.load() }
    }

    private var shopHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(shop.shopType.accentColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: shop.shopType.icon)
                    .font(.title3.bold())
                    .foregroundStyle(shop.shopType.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                TextField("Shop name", text: $shop.name)
                    .font(.title2.bold()).textFieldStyle(.plain)
                HStack(spacing: 8) {
                    Picker("", selection: Binding(get: { shop.shopType }, set: { shop.shopType = $0 })) {
                        ForEach(ShopType.allCases, id: \.self) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    .pickerStyle(.menu).labelsHidden().fixedSize()

                    Text("·").foregroundStyle(.secondary)

                    Picker("", selection: Binding(get: { shop.quality }, set: { shop.quality = $0 })) {
                        ForEach(ShopQuality.allCases, id: \.self) { q in
                            Text(q.rawValue).tag(q)
                        }
                    }
                    .pickerStyle(.menu).labelsHidden().fixedSize()

                    if let city = shopCity {
                        Text("·").foregroundStyle(.secondary)
                        Text(shopCountry != nil ? "\(shopCountry!.name) › \(city.name)" : city.name)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Picker("Quest", selection: Binding(get: { shop.questType }, set: { shop.questType = $0 })) {
                ForEach(ShopQuestType.allCases, id: \.self) { qt in
                    Text(qt.rawValue).tag(qt)
                }
            }
            .pickerStyle(.menu)
            .tint(shop.questType == .none ? .secondary : shop.questType.color)
            .fixedSize()
        }
    }

    private var ownerGroupBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Owner", systemImage: "person.fill")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                    Spacer()
                    if let npc = linkedNPC {
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle.fill").font(.caption2).foregroundStyle(.teal)
                            Text(npc.name).font(.caption2.bold()).foregroundStyle(.teal)
                            Button {
                                sectionState.selectedNPC = npc
                                sectionState.selectedSection = .npcLibrary
                            } label: {
                                Image(systemName: "arrow.right.circle").font(.caption2).foregroundStyle(.teal)
                            }
                            .buttonStyle(.plain).help("Open in NPC Library")
                            Button {
                                shop.ownerNPCID = nil
                            } label: {
                                Image(systemName: "xmark.circle").font(.caption2).foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain).help("Unlink NPC")
                        }
                    } else {
                        Menu {
                            Button {
                                showNPCPicker = true
                            } label: {
                                Label("Link Existing NPC", systemImage: "person.circle")
                            }
                            Button {
                                showCreateNPC = true
                            } label: {
                                Label("Create New NPC", systemImage: "person.badge.plus")
                            }
                        } label: {
                            Label("Link NPC", systemImage: "person.badge.plus")
                                .font(.caption2)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .foregroundStyle(.teal)
                    }
                }
                TextField("Owner name", text: $shop.ownerName)
                    .textFieldStyle(.roundedBorder)
                TextField("Owner notes", text: $shop.ownerNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3, reservesSpace: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var linkedStoryGroupBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Linked Story", systemImage: "scroll.fill")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                    Spacer()
                    if shop.storyID != nil {
                        Button {
                            showStoryPicker = true
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath").font(.caption2).foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain).help("Change story")
                        Button {
                            shop.storyID = nil
                            shop.linkedStoryName = ""
                        } label: {
                            Image(systemName: "xmark.circle").font(.caption2).foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain).help("Unlink story")
                    } else {
                        Button {
                            showStoryPicker = true
                        } label: {
                            Label("Link Story", systemImage: "plus.circle")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain).foregroundStyle(.indigo)
                    }
                }

                if let story = linkedStory {
                    HStack(spacing: 10) {
                        Image(systemName: story.status.systemImage)
                            .foregroundStyle(story.status.color)
                            .font(.subheadline)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(story.name).font(.subheadline)
                            Text("Level \(story.level) · \(story.status.rawValue)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            sectionState.selectedStory = story
                            sectionState.selectedSection = .stories
                        } label: {
                            Label("Open", systemImage: "arrow.right.circle.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.plain).foregroundStyle(.indigo)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.15)))
                } else if !shop.linkedStoryName.isEmpty {
                    Text(shop.linkedStoryName).font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("No story linked").font(.caption).foregroundStyle(.tertiary).padding(.vertical, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var descriptionGroupBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label("Description", systemImage: "text.alignleft")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                TextEditor(text: $shop.shopDescription)
                    .font(.callout).frame(minHeight: 72).scrollContentBackground(.hidden)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var financesGroupBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Label("Finances", systemImage: "dollarsign.circle.fill")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                HStack(spacing: 0) {
                    financeCell(label: "Starting Gold", value: $shop.startingGold, color: .secondary)
                    Divider()
                    financeCell(label: "Net Earned", value: $shop.totalEarned, color: shop.totalEarned >= 0 ? .green : .red)
                    Divider()
                    VStack(spacing: 4) {
                        Text("Balance").font(.caption2).foregroundStyle(.secondary)
                        Text("\(Int(shop.currentBalance)) gp")
                            .font(.callout.bold().monospacedDigit())
                            .foregroundStyle(shop.currentBalance >= 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.red))
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 56)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.15)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var inventoryGroupBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Inventory", systemImage: "list.bullet.rectangle.fill")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(shop.inventory.count) items")
                        .font(.caption2).foregroundStyle(.tertiary)
                    Button {
                        showRandomizeConfirm = true
                    } label: {
                        Label("Randomize", systemImage: "dice.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain).foregroundStyle(.purple)
                    Button {
                        showSellCatalog = true
                    } label: {
                        Label("Sell Item", systemImage: "arrow.down.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain).foregroundStyle(.orange)
                    Button {
                        showCatalogBrowser = true
                    } label: {
                        Label("Add Items", systemImage: "plus.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain).foregroundStyle(.blue)
                }

                if shop.inventory.isEmpty {
                    Text("No items in inventory. Tap Add Items to stock the shop.")
                        .font(.caption).foregroundStyle(.tertiary).padding(.vertical, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(shop.inventory) { entry in
                            inventoryRow(entry)
                            if entry.id != shop.inventory.last?.id {
                                Divider().padding(.leading, 36)
                            }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.15)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func financeCell(label: String, value: Binding<Double>, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 3) {
                TextField("0", value: value, format: .number)
                    .font(.callout.bold().monospacedDigit())
                    .foregroundStyle(color)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Text("gp").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func inventoryRow(_ entry: ShopInventoryEntry) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(entry.itemType.accentColor.opacity(0.15))
                    .frame(width: 26, height: 26)
                Image(systemName: entry.itemType.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(entry.itemType.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).font(.subheadline)
                    .strikethrough(!entry.inStock, color: .secondary)
                    .foregroundStyle(entry.inStock ? .primary : .secondary)
                HStack(spacing: 6) {
                    Text(entry.category).font(.caption2).foregroundStyle(.tertiary)
                    if entry.customPrice != nil && !entry.catalogCost.isEmpty && entry.catalogCost != "—" {
                        Text("catalog: \(entry.catalogCost)").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    mutateEntry(id: entry.id) { e in if e.quantity > 0 { e.quantity -= 1 } }
                } label: {
                    Image(systemName: "minus.circle").font(.caption).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                Text("\(entry.quantity)").font(.caption.monospacedDigit()).frame(minWidth: 22, alignment: .center)
                Button {
                    mutateEntry(id: entry.id) { e in e.quantity += 1 }
                } label: {
                    Image(systemName: "plus.circle").font(.caption).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    if let customPrice = entry.customPrice {
                        TextField("0", value: Binding(
                            get: { customPrice },
                            set: { v in mutateEntry(id: entry.id) { e in e.customPrice = v } }
                        ), format: .number)
                        .font(.caption.monospacedDigit())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 58)
                        .multilineTextAlignment(.trailing)
                        Text("gp").font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text(entry.catalogCost.isEmpty || entry.catalogCost == "—" ? "—" : entry.catalogCost)
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Button {
                            mutateEntry(id: entry.id) { e in e.customPrice = 0 }
                        } label: {
                            Image(systemName: "pencil.circle").font(.caption2).foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain).help("Set custom price")
                    }
                }
                if entry.customPrice != nil {
                    Button("catalog") {
                        mutateEntry(id: entry.id) { e in e.customPrice = nil }
                    }
                    .font(.caption2).foregroundStyle(.tertiary).buttonStyle(.plain)
                }
            }
            .frame(minWidth: 80, alignment: .trailing)

            Button {
                pendingBuyEntry = entry
            } label: {
                Image(systemName: "cart.fill")
                    .foregroundStyle(Color.green.opacity(0.8))
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Player buys — choose character")
            .disabled(entry.quantity == 0)

            Toggle("", isOn: Binding(
                get: { entry.inStock },
                set: { v in mutateEntry(id: entry.id) { e in e.inStock = v } }
            ))
            .toggleStyle(.switch).controlSize(.mini).help("In stock")

            Button {
                itemToDetail = catalogItem(for: entry)
            } label: {
                Image(systemName: "info.circle").foregroundStyle(.secondary).font(.caption)
            }
            .buttonStyle(.plain)
            .help("Item details")
            .disabled(catalogItem(for: entry) == nil)

            Button {
                var inv = shop.inventory
                inv.removeAll { $0.id == entry.id }
                shop.setInventory(inv)
            } label: {
                Image(systemName: "minus.circle.fill").foregroundStyle(.red.opacity(0.6)).font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
    }

    private func priceGold(for entry: ShopInventoryEntry) -> Double {
        if let p = entry.customPrice { return p }
        let raw = entry.catalogCost.components(separatedBy: " ").first ?? ""
        return Double(raw.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private func parseWeight(_ weight: String?) -> Double {
        guard let w = weight else { return 0 }
        let raw = w.components(separatedBy: " ").first ?? ""
        return Double(raw.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private func spellDefaultCost(for item: CatalogItem) -> String? {
        guard item.type == .spell else { return nil }
        let lvl = item.level?.lowercased() ?? ""
        switch lvl {
        case "cantrip", "0": return "25 gp"
        case _ where lvl.hasPrefix("1"): return "50 gp"
        case _ where lvl.hasPrefix("2"): return "250 gp"
        case _ where lvl.hasPrefix("3"): return "500 gp"
        case _ where lvl.hasPrefix("4"): return "2,500 gp"
        case _ where lvl.hasPrefix("5"): return "5,000 gp"
        case _ where lvl.hasPrefix("6"): return "15,000 gp"
        case _ where lvl.hasPrefix("7"): return "25,000 gp"
        case _ where lvl.hasPrefix("8"): return "50,000 gp"
        case _ where lvl.hasPrefix("9"): return "250,000 gp"
        default: return nil
        }
    }

    private func mutateEntry(id: UUID, mutation: (inout ShopInventoryEntry) -> Void) {
        var inv = shop.inventory
        guard let i = inv.firstIndex(where: { $0.id == id }) else { return }
        mutation(&inv[i])
        shop.setInventory(inv)
    }

    private func catalogItem(for entry: ShopInventoryEntry) -> CatalogItem? {
        if let item = catalog.item(slug: entry.slug) { return item }
        return CustomCatalogItem.fromSlug(entry.slug, in: allCustomItems)?.toCatalogItem()
    }
}

// MARK: - BuyPCPickerSheet

struct BuyPCPickerSheet: View {
    let entry: ShopInventoryEntry
    let suggestedPrice: Double
    let suggestedPriceString: String
    let pcs: [PlayerCharacter]
    let onConfirm: (PlayerCharacter, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPC: PlayerCharacter? = nil
    @State private var priceText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedPC == nil ? "Who is buying?" : "Final Price").font(.headline)
                    Text(entry.name).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if selectedPC != nil {
                    Button {
                        selectedPC = nil
                        priceText = ""
                    } label: {
                        Image(systemName: "chevron.left").font(.caption)
                        Text("Back")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
                Button("Cancel") { dismiss() }.buttonStyle(.borderless)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            Divider()

            if let pc = selectedPC {
                VStack(spacing: 20) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Text(pc.combatSymbol.isEmpty ? String(pc.name.prefix(1)) : pc.combatSymbol)
                                .font(.title3.bold()).foregroundStyle(.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pc.name).font(.subheadline.bold())
                            Text("\(pc.gold) gp in wallet").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    VStack(spacing: 6) {
                        Text("How much does the player actually pay?")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        if !suggestedPriceString.isEmpty {
                            Text("Listed price: \(suggestedPriceString)")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("Amount", text: $priceText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                        Text("gp").font(.callout)
                    }

                    Button("Confirm Purchase") {
                        let price = Double(priceText.replacingOccurrences(of: ",", with: "")) ?? 0
                        onConfirm(pc, price)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(priceText.isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if pcs.isEmpty {
                    Text("No characters in this campaign")
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    List {
                        ForEach(pcs) { pc in
                            Button {
                                selectedPC = pc
                                if suggestedPrice > 0 {
                                    priceText = String(Int(suggestedPrice))
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.15))
                                            .frame(width: 34, height: 34)
                                        Text(pc.combatSymbol.isEmpty ? String(pc.name.prefix(1)) : pc.combatSymbol)
                                            .font(.subheadline.bold()).foregroundStyle(.blue)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pc.name).font(.subheadline)
                                        if !pc.playerName.isEmpty {
                                            Text(pc.playerName).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text("\(pc.gold) gp").font(.caption).foregroundStyle(.secondary)
                                    Text("Lv \(pc.level)").font(.caption.bold())
                                        .padding(.horizontal, 7).padding(.vertical, 3)
                                        .background(Color.blue.opacity(0.12))
                                        .foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(width: 360, height: 400)
    }
}

// MARK: - SellPriceSheet

struct SellPriceSheet: View {
    let item: CatalogItem
    let suggestedPrice: String?
    let onConfirm: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var priceText = ""

    private var displayPrice: String? {
        if !item.cost.isEmpty && item.cost != "—" { return item.cost }
        return suggestedPrice
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 32)).foregroundStyle(.orange)
                Text("Player Sells to Shop").font(.headline)
                Text(item.name).font(.subheadline).foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text("How much did the player pay for this item?")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                if let p = displayPrice {
                    Text("Catalog price: \(p)")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 8) {
                TextField("Amount", text: $priceText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
                Text("gp").font(.callout)
            }

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Confirm") {
                    let price = Double(priceText.replacingOccurrences(of: ",", with: "")) ?? 0
                    onConfirm(price)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(priceText.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 300)
    }
}

// MARK: - ShopOwnerNPCPickerSheet

struct ShopOwnerNPCPickerSheet: View {
    let npcs: [NPCTemplate]
    let onSelect: (NPCTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var filtered: [NPCTemplate] {
        if search.isEmpty { return npcs }
        return npcs.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Link NPC as Owner").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.borderless)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            Divider()

            TextField("Search NPCs...", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16).padding(.vertical, 10)

            Divider()

            List {
                ForEach(filtered) { npc in
                    Button {
                        onSelect(npc)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.teal).font(.title3)
                            Text(npc.name).font(.subheadline)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if filtered.isEmpty {
                    Text(npcs.isEmpty ? "No NPCs in this campaign" : "No results")
                        .foregroundStyle(.secondary).font(.callout)
                        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 20)
                }
            }
        }
        .frame(width: 360, height: 400)
    }
}

// MARK: - ShopStoryPickerSheet

struct ShopStoryPickerSheet: View {
    let stories: [Story]
    let onSelect: (Story) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var filtered: [Story] {
        if search.isEmpty { return stories }
        return stories.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Link Story").font(.headline)
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
                ForEach(filtered) { story in
                    Button {
                        onSelect(story)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: story.status.systemImage)
                                .foregroundStyle(story.status.color).font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(story.name).font(.subheadline)
                                Text("Level \(story.level) · \(story.status.rawValue)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if filtered.isEmpty {
                    Text(stories.isEmpty ? "No stories in this campaign" : "No results")
                        .foregroundStyle(.secondary).font(.callout)
                        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 20)
                }
            }
        }
        .frame(width: 360, height: 400)
    }
}
