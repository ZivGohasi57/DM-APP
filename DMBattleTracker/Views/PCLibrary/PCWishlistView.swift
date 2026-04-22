import SwiftUI
import SwiftData

struct PCWishlistView: View {
    let pc: PlayerCharacter
    let campaign: Campaign

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var catalog = CatalogService.shared
    @Query private var wishlistItems: [PCWishlistItem]
    @Query private var shops: [Shop]
    @Query private var cities: [City]
    @Query private var countries: [Country]

    @Query private var allStories: [Story]
    @State private var showCatalogBrowser = false

    init(pc: PlayerCharacter, campaign: Campaign) {
        self.pc = pc
        self.campaign = campaign
        let pcID = pc.id
        let cid = campaign.id
        _wishlistItems = Query(
            filter: #Predicate<PCWishlistItem> { $0.pcID == pcID },
            sort: [SortDescriptor(\PCWishlistItem.priorityRaw), SortDescriptor(\PCWishlistItem.name)]
        )
        _shops = Query(filter: #Predicate<Shop> { $0.campaignID == cid })
        _cities = Query(filter: #Predicate<City> { $0.campaignID == cid })
        _countries = Query(filter: #Predicate<Country> { $0.campaignID == cid })
        _allStories = Query(filter: #Predicate<Story> { $0.campaignID == cid })
    }

    var grouped: [(WishlistPriority, [PCWishlistItem])] {
        WishlistPriority.allCases.compactMap { priority in
            let items = wishlistItems.filter { $0.priority == priority }
            return items.isEmpty ? nil : (priority, items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wishlist").font(.headline)
                    Text(pc.name).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showCatalogBrowser = true
                } label: {
                    Label("Add Item", systemImage: "plus.circle.fill").font(.callout)
                }
                .buttonStyle(.plain).foregroundStyle(.blue)
                Divider().frame(height: 20)
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent).controlSize(.small)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            Divider()

            if wishlistItems.isEmpty {
                ContentUnavailableView(
                    "Empty Wishlist",
                    systemImage: "heart.circle",
                    description: Text("Add items \(pc.name) wants to acquire.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(grouped, id: \.0) { priority, items in
                        Section {
                            ForEach(items) { item in
                                wishlistRow(item)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            modelContext.delete(item)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Circle().fill(priority.color).frame(width: 8, height: 8)
                                Text(priority.label).font(.caption.bold()).foregroundStyle(priority.color)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 580, height: 520)
        .sheet(isPresented: $showCatalogBrowser) {
            CatalogBrowserView(campaignID: campaign.id) { item in
                guard !wishlistItems.contains(where: { $0.slug == item.slug }) else { return }
                let entry = PCWishlistItem(pcID: pc.id, campaignID: campaign.id, item: item)
                modelContext.insert(entry)
            }
        }
        .task { await catalog.load() }
    }

    @ViewBuilder
    private func wishlistRow(_ item: PCWishlistItem) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(item.itemType.accentColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: item.itemType.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(item.itemType.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.subheadline)
                    .strikethrough(item.acquired, color: .secondary)
                    .foregroundStyle(item.acquired ? .secondary : .primary)

                let availability = findAvailability(slug: item.slug)
                let storyRewards = findStoryRewards(slug: item.slug)
                if availability.isEmpty && storyRewards.isEmpty {
                    Text("Not available in any shop or quest")
                        .font(.caption2).foregroundStyle(.tertiary)
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        if !storyRewards.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(storyRewards.prefix(2), id: \.storyID) { reward in
                                    HStack(spacing: 3) {
                                        Image(systemName: "scroll.fill").font(.system(size: 8))
                                        Text(reward.locationText)
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.indigo)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Color.indigo.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                                if storyRewards.count > 2 {
                                    Text("+\(storyRewards.count - 2)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        if !availability.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(availability.prefix(2), id: \.shopID) { avail in
                                    HStack(spacing: 3) {
                                        Image(systemName: "storefront").font(.system(size: 8))
                                        Text("\(avail.countryName) › \(avail.cityName) › \(avail.shopName) (\(avail.price))")
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Color.green.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                                if availability.count > 2 {
                                    Text("+\(availability.count - 2)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if !item.notes.isEmpty {
                    Text(item.notes).font(.caption2).foregroundStyle(.secondary)
                }
            }

            Spacer()

            Menu {
                ForEach(WishlistPriority.allCases, id: \.self) { p in
                    Button {
                        item.priority = p
                    } label: {
                        if item.priority == p {
                            Label(p.label, systemImage: "checkmark")
                        } else {
                            Text(p.label)
                        }
                    }
                }
            } label: {
                Text(item.priority.shortLabel)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(item.priority.color.opacity(0.15))
                    .foregroundStyle(item.priority.color)
                    .clipShape(Capsule())
            }
            .menuStyle(.borderlessButton).fixedSize()

            Toggle("", isOn: Binding(get: { item.acquired }, set: { item.acquired = $0 }))
                .toggleStyle(.switch).controlSize(.mini).help("Mark as acquired")

            Button {
                modelContext.delete(item)
            } label: {
                Image(systemName: "trash").font(.caption).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain).help("Remove from wishlist")
        }
        .padding(.vertical, 4)
    }

    private func findStoryRewards(slug: String) -> [StoryRewardAvailability] {
        let cityMap = Dictionary(uniqueKeysWithValues: cities.map { ($0.id, $0) })
        let countryMap = Dictionary(uniqueKeysWithValues: countries.map { ($0.id, $0) })
        return allStories.compactMap { story in
            guard story.linkedItems.contains(where: { $0.slug == slug }) else { return nil }
            var parts = [story.name]
            if let cityID = story.locationCityID, let city = cityMap[cityID] {
                let countryName = countryMap[city.countryID]?.name ?? ""
                if !countryName.isEmpty { parts.append(countryName) }
                parts.append(city.name)
            }
            return StoryRewardAvailability(storyID: story.id, locationText: parts.joined(separator: " › "))
        }
    }

    private func findAvailability(slug: String) -> [WishlistAvailability] {
        let cityMap = Dictionary(uniqueKeysWithValues: cities.map { ($0.id, $0) })
        let countryMap = Dictionary(uniqueKeysWithValues: countries.map { ($0.id, $0) })

        return shops.compactMap { shop in
            guard let entry = shop.inventory.first(where: { $0.slug == slug && $0.inStock }) else { return nil }
            guard let city = cityMap[shop.cityID] else { return nil }
            let countryName = countryMap[city.countryID]?.name ?? "Unknown"
            return WishlistAvailability(
                countryName: countryName,
                cityName: city.name,
                shopName: shop.name,
                price: entry.displayPrice,
                shopID: shop.id
            )
        }
    }
}

struct StoryRewardAvailability {
    var storyID: UUID
    var locationText: String
}
