import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct CampaignSelectionView: View {
    var onSelect: (Campaign) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Campaign.createdAt) private var campaigns: [Campaign]
    @State private var showCreateSheet: Bool = false
    @State private var campaignToDelete: Campaign? = nil
    @State private var showImporter: Bool = false
    @State private var importError: String? = nil

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.09, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Divider().opacity(0.3)

                if let err = importError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        Text(err).font(.callout).foregroundStyle(.red)
                        Spacer()
                        Button { importError = nil } label: { Image(systemName: "xmark") }
                            .buttonStyle(.borderless).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 28).padding(.vertical, 10)
                    .background(Color.red.opacity(0.08))
                    Divider().opacity(0.3)
                }

                if campaigns.isEmpty {
                    emptyCampaignState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(campaigns) { campaign in
                                CampaignCard(campaign: campaign) {
                                    onSelect(campaign)
                                } onDelete: {
                                    campaignToDelete = campaign
                                }
                            }
                        }
                        .padding(28)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateCampaignSheet { name in
                let c = Campaign(name: name)
                modelContext.insert(c)
                onSelect(c)
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                let campaign = try importCampaignBundle(from: data, into: modelContext)
                onSelect(campaign)
            } catch {
                importError = "Import failed: \(error.localizedDescription)"
            }
        }
        .alert("Delete Campaign", isPresented: Binding(
            get: { campaignToDelete != nil },
            set: { if !$0 { campaignToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let c = campaignToDelete { modelContext.delete(c) }
                campaignToDelete = nil
            }
            Button("Cancel", role: .cancel) { campaignToDelete = nil }
        } message: {
            if let c = campaignToDelete {
                Text("Delete \"\(c.name)\"? This removes the campaign record but not its characters, bestiary, or encounters.")
            }
        }
    }

    var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DM Tracker")
                    .font(.largeTitle.bold())
                Text("Select a campaign to continue")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showImporter = true
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
                    .font(.headline)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            Button {
                showCreateSheet = true
            } label: {
                Label("New Campaign", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.5, green: 0.3, blue: 0.9))
            .controlSize(.large)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
    }

    var emptyCampaignState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "scroll.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color(red: 0.5, green: 0.3, blue: 0.9).opacity(0.6))
            Text("No Campaigns Yet")
                .font(.title2.bold())
            Text("Create your first campaign to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showCreateSheet = true
            } label: {
                Label("Create Campaign", systemImage: "plus")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.5, green: 0.3, blue: 0.9))
            Spacer()
        }
    }
}

struct CampaignCard: View {
    @Bindable var campaign: Campaign
    var onOpen: () -> Void
    var onDelete: () -> Void
    @State private var isEditing: Bool = false
    @State private var editName: String = ""

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.5, green: 0.3, blue: 0.9).opacity(0.18))
                    .frame(width: 52, height: 52)
                Image(systemName: "shield.fill")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.7, green: 0.5, blue: 1.0))
            }

            VStack(alignment: .leading, spacing: 5) {
                if isEditing {
                    TextField("Campaign name", text: $editName)
                        .font(.title3.bold())
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            if !editName.trimmingCharacters(in: .whitespaces).isEmpty {
                                campaign.name = editName.trimmingCharacters(in: .whitespaces)
                            }
                            isEditing = false
                        }
                } else {
                    Text(campaign.name)
                        .font(.title3.bold())
                }
                Text("Created \(campaign.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    editName = campaign.name
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Rename campaign")

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.borderless)
                .help("Delete campaign")

                Button {
                    onOpen()
                } label: {
                    Label("Open", systemImage: "arrow.right.circle.fill")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.5, green: 0.3, blue: 0.9))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

struct CreateCampaignSheet: View {
    var onCreate: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(red: 0.7, green: 0.5, blue: 1.0))
                Text("New Campaign")
                    .font(.title2.bold())
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            VStack(spacing: 16) {
                SheetFormRow(label: "Name") {
                    TextField("e.g. The Curse of Strahd", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                }
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 24)
            Divider()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    onCreate(trimmed.isEmpty ? "New Campaign" : trimmed)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.5, green: 0.3, blue: 0.9))
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 420, height: 260)
    }
}
