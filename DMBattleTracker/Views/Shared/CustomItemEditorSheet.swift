import SwiftUI
import SwiftData

struct CustomItemEditorSheet: View {
    let campaignID: UUID
    var editingItem: CustomCatalogItem? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var itemType: CatalogItemType = .magicItem
    @State private var category = ""
    @State private var cost = ""
    @State private var desc = ""
    @State private var weight = ""
    @State private var rarityRaw = CatalogItemRarity.unknown.rawValue
    @State private var attunement = false
    @State private var acString = ""
    @State private var damageDice = ""
    @State private var spellLevel = ""
    @State private var school = ""
    @State private var castingTime = ""
    @State private var spellRange = ""
    @State private var components = ""
    @State private var duration = ""
    @State private var concentration = false
    @State private var ritual = false

    var isEditing: Bool { editingItem != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "Edit Item" : "New Custom Item").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.borderless)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Type", selection: $itemType) {
                        ForEach(CatalogItemType.allCases, id: \.self) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isEditing)

                    field("Name") {
                        TextField("Item name", text: $name).textFieldStyle(.roundedBorder)
                    }
                    field("Category") {
                        TextField(categoryPlaceholder, text: $category).textFieldStyle(.roundedBorder)
                    }

                    if itemType != .spell {
                        field("Cost") {
                            TextField("e.g. 500 gp", text: $cost).textFieldStyle(.roundedBorder)
                        }
                        field("Weight") {
                            TextField("e.g. 4 lb.", text: $weight).textFieldStyle(.roundedBorder)
                        }
                    }

                    if itemType == .magicItem {
                        field("Rarity") {
                            Picker("", selection: $rarityRaw) {
                                ForEach(CatalogItemRarity.allCases, id: \.self) { r in
                                    Text(r.rawValue).tag(r.rawValue)
                                }
                            }
                            .pickerStyle(.menu).fixedSize()
                        }
                        Toggle("Requires Attunement", isOn: $attunement)
                    }

                    if itemType == .weapon {
                        field("Damage Dice") {
                            TextField("e.g. 1d8", text: $damageDice).textFieldStyle(.roundedBorder)
                        }
                    }

                    if itemType == .armor {
                        field("AC") {
                            TextField("e.g. 13 + Dex modifier", text: $acString).textFieldStyle(.roundedBorder)
                        }
                    }

                    if itemType == .spell {
                        field("Level") {
                            TextField("e.g. 3rd-level, Cantrip", text: $spellLevel).textFieldStyle(.roundedBorder)
                        }
                        field("School") {
                            TextField("e.g. Evocation", text: $school).textFieldStyle(.roundedBorder)
                        }
                        field("Casting Time") {
                            TextField("e.g. 1 action", text: $castingTime).textFieldStyle(.roundedBorder)
                        }
                        field("Range") {
                            TextField("e.g. 60 feet", text: $spellRange).textFieldStyle(.roundedBorder)
                        }
                        field("Components") {
                            TextField("e.g. V, S, M (a pinch of salt)", text: $components).textFieldStyle(.roundedBorder)
                        }
                        field("Duration") {
                            TextField("e.g. 1 minute", text: $duration).textFieldStyle(.roundedBorder)
                        }
                        HStack(spacing: 20) {
                            Toggle("Concentration", isOn: $concentration)
                            Toggle("Ritual", isOn: $ritual)
                        }
                    }

                    field("Description") {
                        TextEditor(text: $desc)
                            .font(.callout)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.2)))
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button(isEditing ? "Save" : "Create") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
        }
        .frame(width: 460, height: 620)
        .onAppear { loadExisting() }
    }

    private var categoryPlaceholder: String {
        switch itemType {
        case .weapon: return "e.g. Martial Melee Weapons"
        case .armor: return "e.g. Light Armor"
        case .magicItem: return "e.g. Wondrous Item"
        case .spell: return "e.g. Evocation Spell"
        }
    }

    @ViewBuilder
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.bold()).foregroundStyle(.secondary)
            content()
        }
    }

    private func loadExisting() {
        guard let item = editingItem else { return }
        name = item.name
        itemType = item.itemType
        category = item.category
        cost = item.cost
        desc = item.desc
        weight = item.weight
        rarityRaw = item.rarityRaw
        attunement = item.attunement
        acString = item.acString
        damageDice = item.damageDice
        spellLevel = item.spellLevel
        school = item.school
        castingTime = item.castingTime
        spellRange = item.spellRange
        components = item.components
        duration = item.duration
        concentration = item.concentration
        ritual = item.ritual
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let target: CustomCatalogItem
        if let item = editingItem {
            target = item
        } else {
            target = CustomCatalogItem(campaignID: campaignID, name: trimmed, itemType: itemType)
            modelContext.insert(target)
        }
        target.name = trimmed
        target.category = category
        target.cost = cost
        target.desc = desc
        target.weight = weight
        target.rarityRaw = rarityRaw
        target.attunement = attunement
        target.acString = acString
        target.damageDice = damageDice
        target.spellLevel = spellLevel
        target.school = school
        target.castingTime = castingTime
        target.spellRange = spellRange
        target.components = components
        target.duration = duration
        target.concentration = concentration
        target.ritual = ritual
        dismiss()
    }
}
