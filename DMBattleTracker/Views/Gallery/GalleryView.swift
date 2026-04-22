import SwiftUI
import SwiftData
import AppKit

// MARK: - Folder selection

enum GallerySelection: Hashable {
    case world
    case cities
    case folder(UUID)
}

// MARK: - GalleryView

struct GalleryView: View {
    let campaign: Campaign

    @Environment(\.modelContext) private var modelContext
    @Environment(GalleryPresentationState.self) private var presentationState
    @Environment(\.openWindow) private var openWindow

    @Query private var worldMaps: [WorldMapRecord]
    @Query private var countries: [Country]
    @Query private var cities: [City]
    @Query private var folders: [GalleryFolder]
    @Query private var images: [GalleryImage]

    @State private var selection: GallerySelection? = .world
    @State private var showAddFolder = false
    @State private var showImageImporter = false
    @State private var showPresentConfirm = false
    @State private var pendingPresentItems: [GalleryPresentationItem]? = nil
    @State private var pendingPresentIndex: Int = 0
    @State private var folderToDelete: GalleryFolder? = nil
    @State private var imageIndexToDelete: Int? = nil
    @State private var showWorldMapImporter = false

    init(campaign: Campaign) {
        self.campaign = campaign
        let cid = campaign.id
        _worldMaps  = Query(filter: #Predicate<WorldMapRecord> { $0.campaignID == cid })
        _countries  = Query(
            filter: #Predicate<Country> { $0.campaignID == cid },
            sort: [SortDescriptor(\Country.sortOrder), SortDescriptor(\Country.name)]
        )
        _cities     = Query(filter: #Predicate<City> { $0.campaignID == cid }, sort: [SortDescriptor(\City.name)])
        _folders    = Query(
            filter: #Predicate<GalleryFolder> { $0.campaignID == cid },
            sort: [SortDescriptor(\GalleryFolder.sortOrder), SortDescriptor(\GalleryFolder.name)]
        )
        _images     = Query(
            filter: #Predicate<GalleryImage> { $0.campaignID == cid },
            sort: [SortDescriptor(\GalleryImage.sortOrder), SortDescriptor(\GalleryImage.createdAt)]
        )
    }

    // MARK: - Cheap has-content check (no Data copies)

    private var hasContent: Bool {
        switch selection {
        case .world:          return worldMaps.first?.imageData != nil
        case .cities:         return cities.contains { $0.mapImageData != nil }
        case .folder(let id): return images.contains { $0.folderID == id }
        case nil:             return false
        }
    }

    // Built only when user taps Present — never during render
    private func buildPresentationItems() -> [GalleryPresentationItem] {
        switch selection {
        case .world:
            if let data = worldMaps.first?.imageData { return [.init(title: "World Map", data: data)] }
            return []
        case .cities:
            return cities.compactMap { c in
                c.mapImageData.map { .init(title: c.name, data: $0, symbolData: c.symbolImageData) }
            }
        case .folder(let id):
            return images.filter { $0.folderID == id }
                .map { .init(title: $0.title.isEmpty ? "Image" : $0.title, data: $0.imageData) }
        case nil:
            return []
        }
    }

    private var isEditableFolder: Bool {
        if case .folder(_) = selection { return true }
        return false
    }

    private var selectedFolderID: UUID? {
        if case .folder(let id) = selection { return id }
        return nil
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(minWidth: 200, maxWidth: 240)
            Divider()
            mainContent.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Gallery")
        .task { ensureBattleFolder() }
        .sheet(isPresented: $showAddFolder) {
            AddGalleryFolderSheet(campaignID: campaign.id, sortOrder: folders.count)
        }
        .fileImporter(
            isPresented: $showImageImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result, let folderID = selectedFolderID else { return }
            let maxOrder = (images.filter { $0.folderID == folderID }.map { $0.sortOrder }.max() ?? -1)
            var offset = 0
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url),
                   let nsImage = NSImage(data: data),
                   let png = nsImage.galleryPngData {
                    let img = GalleryImage(
                        folderID: folderID,
                        campaignID: campaign.id,
                        imageData: png,
                        title: url.deletingPathExtension().lastPathComponent,
                        sortOrder: maxOrder + offset + 1
                    )
                    modelContext.insert(img)
                    offset += 1
                }
            }
        }
        .alert("Present on Screen?", isPresented: $showPresentConfirm) {
            Button("Present") {
                if let items = pendingPresentItems {
                    presentationState.items = items
                    presentationState.currentIndex = pendingPresentIndex
                    openWindow(id: "gallery-presentation")
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will open the presentation window in full screen.")
        }
        .alert("Delete Folder?", isPresented: Binding(
            get: { folderToDelete != nil },
            set: { if !$0 { folderToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let f = folderToDelete { deleteFolder(f) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let f = folderToDelete { Text("Delete '\(f.name)' and all its images? This cannot be undone.") }
        }
        .alert("Delete Image?", isPresented: Binding(
            get: { imageIndexToDelete != nil },
            set: { if !$0 { imageIndexToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let idx = imageIndexToDelete { deleteImageAt(idx) }
                imageIndexToDelete = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This image will be permanently deleted.")
        }
        .fileImporter(isPresented: $showWorldMapImporter, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url),
                  let nsImage = NSImage(data: data),
                  let tiff = nsImage.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else { return }
            if let existing = worldMaps.first {
                existing.imageData = png
            } else {
                let rec = WorldMapRecord(campaignID: campaign.id)
                rec.imageData = png
                modelContext.insert(rec)
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section("Built-In") {
                    Label("World", systemImage: "globe.europe.africa.fill")
                        .tag(GallerySelection.world)
                    Label("Cities", systemImage: "building.2.fill")
                        .tag(GallerySelection.cities)
                }
                Section("Folders") {
                    ForEach(folders) { folder in
                        HStack {
                            Label(folder.name, systemImage: "folder.fill")
                            Spacer()
                            let count = images.filter { $0.folderID == folder.id }.count
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2).foregroundStyle(.secondary)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.2)).clipShape(Capsule())
                            }
                        }
                        .tag(GallerySelection.folder(folder.id))
                        .contextMenu {
                            if !folder.isBuiltIn {
                                Button(role: .destructive) { folderToDelete = folder } label: {
                                    Label("Delete Folder", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            Divider()
            Button { showAddFolder = true } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Spacer()
                if isEditableFolder {
                    Button { showImageImporter = true } label: {
                        Label("Add Images", systemImage: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                }
                if hasContent {
                    Button {
                        pendingPresentItems = buildPresentationItems()
                        pendingPresentIndex = 0
                        showPresentConfirm = true
                    } label: {
                        Label("Present on Screen", systemImage: "display")
                    }
                    .buttonStyle(.borderedProminent).tint(.indigo)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 10)

            Divider()

            if !hasContent {
                ContentUnavailableView(emptyTitle, systemImage: emptyIcon, description: Text(emptyDescription))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                listContent
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if case .cities = selection {
                    citiesListContent
                } else if case .world = selection {
                    if let data = worldMaps.first?.imageData {
                        GalleryListRow(
                            title: "World Map",
                            data: data,
                            onPresent: {
                                pendingPresentItems = buildPresentationItems()
                                pendingPresentIndex = 0
                                showPresentConfirm = true
                            },
                            onReplace: { showWorldMapImporter = true },
                            onDelete: nil
                        )
                        Divider()
                    }
                } else if case .folder(let folderID) = selection {
                    let folderImages = images.filter { $0.folderID == folderID }
                    ForEach(Array(folderImages.enumerated()), id: \.element.id) { idx, img in
                        GalleryListRow(
                            title: img.title.isEmpty ? "Image" : img.title,
                            data: img.imageData,
                            onPresent: {
                                pendingPresentItems = buildPresentationItems()
                                pendingPresentIndex = idx
                                showPresentConfirm = true
                            },
                            onDelete: { imageIndexToDelete = idx }
                        )
                        Divider()
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var citiesListContent: some View {
        let citiesWithMap = cities.filter { $0.mapImageData != nil }
        let cityByCountry = Dictionary(grouping: citiesWithMap, by: \.countryID)

        ForEach(countries) { country in
            if let group = cityByCountry[country.id], !group.isEmpty {
                countrySectionHeader(country.name, count: group.count)
                ForEach(group) { city in
                    CityGalleryListRow(city: city) {
                        if let data = city.mapImageData {
                            pendingPresentItems = [GalleryPresentationItem(title: city.name, data: data, symbolData: city.symbolImageData)]
                            pendingPresentIndex = 0
                            showPresentConfirm = true
                        }
                    }
                    Divider().padding(.leading, 134)
                }
            }
        }

        // Cities with no matching country
        let knownCountryIDs = Set(countries.map { $0.id })
        let unassigned = citiesWithMap.filter { !knownCountryIDs.contains($0.countryID) }
        if !unassigned.isEmpty {
            countrySectionHeader("Other", count: unassigned.count)
            ForEach(unassigned) { city in
                CityGalleryListRow(city: city) {
                    if let data = city.mapImageData {
                        pendingPresentItems = [GalleryPresentationItem(title: city.name, data: data, symbolData: city.symbolImageData)]
                        pendingPresentIndex = 0
                        showPresentConfirm = true
                    }
                }
                Divider().padding(.leading, 134)
            }
        }
    }

    private func countrySectionHeader(_ name: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "globe").font(.caption).foregroundStyle(.blue)
            Text(name).font(.caption.bold()).foregroundStyle(.secondary)
            Text("\(count)").font(.caption2).foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.06))
    }

    // MARK: - Empty states

    private var emptyTitle: String {
        switch selection {
        case .world:  return "No World Map"
        case .cities: return "No City Maps"
        default:      return "No Images"
        }
    }

    private var emptyIcon: String {
        switch selection {
        case .world:  return "globe"
        case .cities: return "building.2"
        default:      return "photo.stack"
        }
    }

    private var emptyDescription: String {
        switch selection {
        case .world:  return "Import a world map in the World section."
        case .cities: return "Import maps for cities in the World section."
        default:      return "Click Add Images to import photos."
        }
    }

    // MARK: - Actions

    private func ensureBattleFolder() {
        guard !folders.contains(where: { $0.isBuiltIn && $0.name == "Battle" }) else { return }
        let folder = GalleryFolder(name: "Battle", campaignID: campaign.id, sortOrder: 0, isBuiltIn: true)
        modelContext.insert(folder)
    }

    private func deleteFolder(_ folder: GalleryFolder) {
        images.filter { $0.folderID == folder.id }.forEach { modelContext.delete($0) }
        if selection == .folder(folder.id) { selection = .world }
        modelContext.delete(folder)
    }

    private func deleteImageAt(_ index: Int) {
        guard let folderID = selectedFolderID else { return }
        let folderImages = images.filter { $0.folderID == folderID }
        guard folderImages.indices.contains(index) else { return }
        modelContext.delete(folderImages[index])
    }
}

// MARK: - AsyncThumbnail

private struct AsyncThumbnail: View {
    let data: Data

    @State private var image: NSImage? = nil

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.secondary.opacity(0.15)
                    .overlay { ProgressView().scaleEffect(0.6) }
            }
        }
        .frame(width: 100, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task(id: data) {
            guard image == nil else { return }
            let d = data
            image = await Task.detached(priority: .utility) { NSImage(data: d) }.value
        }
    }
}

// MARK: - GalleryListRow

struct GalleryListRow: View {
    let title: String
    let data: Data
    let onPresent: () -> Void
    var onReplace: (() -> Void)? = nil
    let onDelete: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            AsyncThumbnail(data: data)

            Text(title)
                .font(.subheadline.bold())
                .lineLimit(2)

            Spacer()

            if isHovered {
                if let onReplace {
                    Button(action: onReplace) {
                        Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)
                }
                if let onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onPresent) {
                    Label("Present", systemImage: "display")
                }
                .buttonStyle(.borderedProminent).tint(.indigo)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(isHovered ? Color.secondary.opacity(0.07) : Color.clear)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture { onPresent() }
    }
}

// MARK: - CityGalleryListRow

struct CityGalleryListRow: View {
    @Bindable var city: City
    let onPresent: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            if let data = city.mapImageData {
                AsyncThumbnail(data: data)
            }

            Text(city.name)
                .font(.subheadline.bold())

            Spacer()

            Button {
                city.isMapObtained.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: city.isMapObtained ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(city.isMapObtained ? .green : Color.secondary.opacity(0.5))
                    Text(city.isMapObtained ? "Obtained" : "Not Obtained")
                        .font(.caption.bold())
                        .foregroundStyle(city.isMapObtained ? .green : .secondary)
                }
            }
            .buttonStyle(.plain)

            if isHovered {
                Button(action: onPresent) {
                    Label("Present", systemImage: "display")
                }
                .buttonStyle(.borderedProminent).tint(.indigo)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(isHovered ? Color.secondary.opacity(0.07) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - AddGalleryFolderSheet

struct AddGalleryFolderSheet: View {
    let campaignID: UUID
    let sortOrder: Int

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("New Folder").font(.headline)
            TextField("Folder name", text: $name).textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add") {
                    let folder = GalleryFolder(
                        name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "New Folder" : name,
                        campaignID: campaignID,
                        sortOrder: sortOrder
                    )
                    modelContext.insert(folder)
                    dismiss()
                }
                .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24).frame(width: 320)
    }
}

// MARK: - NSImage extension

private extension NSImage {
    var galleryPngData: Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
