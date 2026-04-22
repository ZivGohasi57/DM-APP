import SwiftUI
import SwiftData

struct ShopsView: View {
    let campaign: Campaign
    let sectionState: SectionState
    @Environment(\.modelContext) private var modelContext
    @Query private var shops: [Shop]
    @Query private var countries: [Country]
    @Query private var cities: [City]
    @StateObject private var catalog = CatalogService.shared

    @State private var showAddSheet = false
    @State private var filterType: ShopType? = nil
    @State private var expandedCountries: Set<UUID> = []
    @State private var expandedCities: Set<UUID> = []

    init(campaign: Campaign, sectionState: SectionState) {
        self.campaign = campaign
        self.sectionState = sectionState
        let cid = campaign.id
        _shops = Query(
            filter: #Predicate<Shop> { $0.campaignID == cid },
            sort: [SortDescriptor(\Shop.sortOrder), SortDescriptor(\Shop.name)]
        )
        _countries = Query(
            filter: #Predicate<Country> { $0.campaignID == cid },
            sort: [SortDescriptor(\Country.sortOrder), SortDescriptor(\Country.name)]
        )
        _cities = Query(
            filter: #Predicate<City> { $0.campaignID == cid },
            sort: [SortDescriptor(\City.name)]
        )
    }

    var filteredShops: [Shop] {
        guard let ft = filterType else { return shops }
        return shops.filter { $0.shopType == ft }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text("\(shops.count) shops").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        Button("All Types") { filterType = nil }
                        Divider()
                        ForEach(ShopType.allCases, id: \.self) { t in
                            Button {
                                filterType = (filterType == t) ? nil : t
                            } label: {
                                Label(t.rawValue, systemImage: t.icon)
                            }
                        }
                    } label: {
                        Image(systemName: filterType == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                            .foregroundStyle(filterType == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.accentColor))
                            .font(.caption)
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                }
                .padding(.horizontal, 12).padding(.vertical, 8)

                Divider()

                List(selection: Binding(get: { sectionState.selectedShop }, set: { sectionState.selectedShop = $0 })) {
                    shopSections
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showAddSheet = true } label: {
                            Label("New Shop", systemImage: "plus")
                        }
                    }
                    ToolbarItem {
                        Button {
                            guard let s = sectionState.selectedShop else { return }
                            modelContext.delete(s)
                            sectionState.selectedShop = nil
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(sectionState.selectedShop == nil)
                    }
                }
            }
            .frame(minWidth: 220, maxWidth: 270)

            Divider()

            Group {
                if let shop = sectionState.selectedShop {
                    ShopDetailView(shop: shop, cities: cities, countries: countries, campaign: campaign, sectionState: sectionState)
                } else {
                    ContentUnavailableView(
                        "No Shop Selected",
                        systemImage: "storefront.fill",
                        description: Text("Create a shop or select one from the list.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Shops")
        .sheet(isPresented: $showAddSheet) {
            AddShopSheet(campaignID: campaign.id, cities: cities, countries: countries)
        }
        .task { await catalog.load() }
    }

    @ViewBuilder
    private var shopSections: some View {
        let displayed = filteredShops

        ForEach(countries) { country in
            let isExpanded = expandedCountries.contains(country.id)
            let countryCities = cities.filter { $0.countryID == country.id }
            let countryShopCount = displayed.filter { shop in
                countryCities.contains(where: { $0.id == shop.cityID })
            }.count

            Section {
                if isExpanded {
                    ForEach(countryCities) { city in
                        let cityShops = displayed.filter { $0.cityID == city.id }
                        if !cityShops.isEmpty {
                            let isCityExpanded = expandedCities.contains(city.id)
                            ShopCityHeader(cityName: city.name, shopCount: cityShops.count, isExpanded: isCityExpanded) {
                                toggleCity(city.id)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                            if isCityExpanded {
                                ForEach(cityShops) { shop in
                                    shopRow(shop).tag(shop)
                                }
                            }
                        }
                    }
                }
            } header: {
                ShopCountryHeader(name: country.name, count: countryShopCount, isExpanded: isExpanded) {
                    toggleCountry(country.id)
                }
            }
        }

        let unassigned = displayed.filter { shop in
            !cities.contains(where: { $0.id == shop.cityID })
        }
        if !unassigned.isEmpty {
            Section("Unassigned") {
                ForEach(unassigned) { shop in shopRow(shop).tag(shop) }
            }
        }

        if displayed.isEmpty && !shops.isEmpty {
            Text("No shops match the filter")
                .foregroundStyle(.secondary).font(.callout)
        }
        if shops.isEmpty {
            Text("No shops yet")
                .foregroundStyle(.secondary).font(.callout)
        }
    }

    @ViewBuilder
    private func shopRow(_ shop: Shop) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(shop.shopType.accentColor.opacity(0.15))
                    .frame(width: 26, height: 26)
                Image(systemName: shop.shopType.icon)
                    .font(.caption.bold())
                    .foregroundStyle(shop.shopType.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(shop.name).font(.subheadline.bold())
                Text(shop.shopType.rawValue).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if let badge = shop.questType.badge {
                Text(badge)
                    .font(.caption2.bold())
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(shop.questType.color.opacity(0.2))
                    .foregroundStyle(shop.questType.color)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 3)
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

struct ShopCountryHeader: View {
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

struct ShopCityHeader: View {
    let cityName: String
    let shopCount: Int
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
            if shopCount > 0 {
                Text("\(shopCount)")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15)).clipShape(Capsule())
            }
        }
        .padding(.leading, 16).padding(.vertical, 3)
    }
}

struct AddShopSheet: View {
    let campaignID: UUID
    let cities: [City]
    let countries: [Country]
    var prefilledCityID: UUID? = nil
    var onCreated: ((Shop) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var shopType: ShopType = .weapons
    @State private var shopQuality: ShopQuality = .medium
    @State private var cityID: UUID? = nil

    var selectedCityName: String {
        cityID.flatMap { id in cities.first { $0.id == id }?.name } ?? "None"
    }

    var prefilledCityName: String? {
        prefilledCityID.flatMap { id in cities.first { $0.id == id }?.name }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("New Shop").font(.headline)

            TextField("Shop name", text: $name).textFieldStyle(.roundedBorder)

            Picker("Type", selection: $shopType) {
                ForEach(ShopType.allCases, id: \.self) { t in
                    Label(t.rawValue, systemImage: t.icon).tag(t)
                }
            }
            .pickerStyle(.menu)

            Picker("Quality", selection: $shopQuality) {
                ForEach(ShopQuality.allCases, id: \.self) { q in
                    Text(q.rawValue).tag(q)
                }
            }
            .pickerStyle(.segmented)

            if let lockedCity = prefilledCityName {
                HStack {
                    Text("City").foregroundStyle(.primary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill").font(.caption).foregroundStyle(.teal)
                        Text(lockedCity).foregroundStyle(.secondary)
                        Text("(from story)").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 6).padding(.horizontal, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Menu {
                    Button("None") { cityID = nil }
                    Divider()
                    ForEach(countries) { country in
                        let cCities = cities.filter { $0.countryID == country.id }
                        if !cCities.isEmpty {
                            Menu(country.name) {
                                ForEach(cCities) { city in
                                    Button {
                                        cityID = city.id
                                    } label: {
                                        if cityID == city.id {
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
                    HStack {
                        Text("City").foregroundStyle(.primary)
                        Spacer()
                        Text(selectedCityName).foregroundStyle(.secondary)
                        Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .padding(.vertical, 6).padding(.horizontal, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add") {
                    let resolvedCityID = prefilledCityID ?? cityID
                    guard let cid = resolvedCityID else { return }
                    let shop = Shop(
                        name: name.isEmpty ? "New Shop" : name,
                        campaignID: campaignID,
                        cityID: cid,
                        shopType: shopType,
                        quality: shopQuality
                    )
                    modelContext.insert(shop)
                    onCreated?(shop)
                    dismiss()
                }
                .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                .disabled(prefilledCityID == nil && cityID == nil)
            }
        }
        .padding(24).frame(width: 360)
        .onAppear { cityID = prefilledCityID }
    }
}
