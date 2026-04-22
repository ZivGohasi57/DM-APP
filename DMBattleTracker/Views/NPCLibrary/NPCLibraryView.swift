import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct NPCLibraryView: View {
    let campaign: Campaign
    @Bindable var sectionState: SectionState

    @Environment(\.modelContext) private var modelContext
    @Query private var npcs: [NPCTemplate]
    @Query private var allStories: [Story]
    @Query private var allShops: [Shop]
    @Query private var allCities: [City]
    @Query private var allCountries: [Country]
    @State private var showAddSheet: Bool = false
    @State private var search = ""
    @State private var showDeleteConfirm = false

    init(campaign: Campaign, sectionState: SectionState) {
        self.campaign = campaign
        _sectionState = Bindable(sectionState)
        let cid = campaign.id
        _npcs = Query(filter: #Predicate<NPCTemplate> { $0.campaignID == cid }, sort: [SortDescriptor(\NPCTemplate.name)])
        _allStories = Query(filter: #Predicate<Story> { $0.campaignID == cid })
        _allShops = Query(filter: #Predicate<Shop> { $0.campaignID == cid })
        _allCities = Query(filter: #Predicate<City> { $0.campaignID == cid })
        _allCountries = Query(filter: #Predicate<Country> { $0.campaignID == cid })
    }

    var filtered: [NPCTemplate] {
        search.isEmpty ? npcs : npcs.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.caption)
                    TextField("Search…", text: $search).textFieldStyle(.plain).font(.callout)
                    if !search.isEmpty {
                        Button { search = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                Divider()
                List(filtered, selection: $sectionState.selectedNPC) { npc in
                    NPCListRow(
                        npc: npc,
                        linkedStory: allStories.first { $0.npcEntries.contains(where: { $0.npcID == npc.id }) },
                        ownedShop: allShops.first { $0.ownerNPCID == npc.id },
                        allCities: allCities,
                        allCountries: allCountries
                    ).tag(npc)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showAddSheet = true } label: { Label("Add NPC", systemImage: "plus") }
                    }
                    ToolbarItem {
                        Button { showDeleteConfirm = true } label: { Label("Delete", systemImage: "trash") }
                        .disabled(sectionState.selectedNPC == nil)
                    }
                }
            }
            .frame(minWidth: 230, maxWidth: 290)

            Divider()

            Group {
                if let npc = sectionState.selectedNPC {
                    NPCDetailView(npc: npc)
                } else {
                    ContentUnavailableView("No NPC Selected", systemImage: "person.2.circle",
                        description: Text("Select an NPC from the list or add a new one."))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("NPC Library")
        .sheet(isPresented: $showAddSheet) { AddNPCSheet(campaignID: campaign.id) }
        .alert("Delete NPC?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                guard let n = sectionState.selectedNPC else { return }
                modelContext.delete(n)
                sectionState.selectedNPC = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let n = sectionState.selectedNPC { Text("Delete '\(n.name)'? This cannot be undone.") }
        }
    }
}

struct NPCListRow: View {
    let npc: NPCTemplate
    var linkedStory: Story? = nil
    var ownedShop: Shop? = nil
    var allCities: [City] = []
    var allCountries: [Country] = []

    var storyCity: City? {
        guard let cid = linkedStory?.locationCityID else { return nil }
        return allCities.first { $0.id == cid }
    }
    var storyCountry: Country? {
        guard let city = storyCity else { return nil }
        return allCountries.first { $0.id == city.countryID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(npc.name).font(.headline)
            HStack(spacing: 10) {
                Label("HP \(npc.maxHP)", systemImage: "heart.fill")
                    .font(.subheadline).foregroundStyle(.green)
                Label("AC \(npc.armorClass)", systemImage: "shield.fill")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if npc.initiative != 0 {
                Label(npc.initiative > 0 ? "+\(npc.initiative)" : "\(npc.initiative)", systemImage: "dice")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let shop = ownedShop {
                HStack(spacing: 4) {
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 9)).foregroundStyle(shop.shopType.accentColor)
                    Text("מנהל: \(shop.name)")
                        .font(.caption).foregroundStyle(shop.shopType.accentColor)
                }
            }
            if let story = linkedStory {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "scroll.fill")
                            .font(.system(size: 9)).foregroundStyle(.indigo)
                        Text(story.name)
                            .font(.caption).foregroundStyle(.indigo)
                    }
                    if storyCity != nil || storyCountry != nil {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin.circle")
                                .font(.system(size: 9)).foregroundStyle(.secondary)
                            Text([storyCountry?.name, storyCity?.name].compactMap { $0 }.joined(separator: " › "))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct NPCDetailView: View {
    @Bindable var npc: NPCTemplate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                GroupBox {
                    Form {
                        TextField("Name", text: $npc.name, prompt: Text("NPC name"))
                        TextField("Max HP", value: $npc.maxHP, format: .number, prompt: Text("30"))
                        TextField("Initiative Bonus", value: $npc.initiative, format: .number, prompt: Text("0"))
                        TextField("Armor Class", value: $npc.armorClass, format: .number, prompt: Text("12"))
                        TextField("Walk Speed (ft)", value: $npc.speed, format: .number, prompt: Text("30"))
                        TextField("Fly Speed (ft, 0 = none)", value: $npc.flySpeed, format: .number, prompt: Text("0"))
                        TextField("Swim Speed (ft, 0 = none)", value: $npc.swimSpeed, format: .number, prompt: Text("0"))
                        TextField("Climb Speed (ft, 0 = none)", value: $npc.climbSpeed, format: .number, prompt: Text("0"))
                        TextField("Burrow Speed (ft, 0 = none)", value: $npc.burrowSpeed, format: .number, prompt: Text("0"))
                        Toggle("Hovering", isOn: $npc.canHover)
                    }
                    .formStyle(.grouped)
                } label: {
                    Label("NPC Info", systemImage: "person.2.circle")
                        .font(.headline)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 0) {
                            ForEach(Ability.allCases) { ability in
                                let scoreBinding = abilityScoreBinding(for: ability)
                                VStack(spacing: 6) {
                                    Text(ability.rawValue)
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    TextField("", value: scoreBinding, format: .number)
                                        .multilineTextAlignment(.center)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 52)
                                    Text(Combatant.formattedModifier(npc.abilityScore(for: ability)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.top, 6)

                        Divider()

                        Text("Saving Throw Proficiencies")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(Ability.allCases) { ability in
                                HStack(spacing: 8) {
                                    let profBinding = Binding<SaveProficiency>(
                                        get: { npc.saveProficiency(for: ability) },
                                        set: { npc.setSaveProficiency($0, for: ability) }
                                    )
                                    let baseMod = Combatant.abilityModifier(npc.abilityScore(for: ability))
                                    let prof = npc.saveProficiency(for: ability)
                                    let saveTotal = baseMod + 2 * prof.multiplier

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ability.rawValue)
                                            .font(.caption.bold())
                                        Text(saveTotal >= 0 ? "+\(saveTotal)" : "\(saveTotal)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(width: 36, alignment: .leading)

                                    Picker("", selection: profBinding) {
                                        ForEach(SaveProficiency.allCases) { p in
                                            Text(p.rawValue).tag(p)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .padding(10)
                } label: {
                    Label("Ability Scores & Saving Throws", systemImage: "person.text.rectangle")
                        .font(.headline)
                }

                GroupBox {
                    DamageResponseGrid(
                        responses: Binding(
                            get: { npc.damageResponses },
                            set: { npc.damageResponses = $0 }
                        )
                    )
                } label: {
                    Label("Damage Responses", systemImage: "shield.lefthalf.filled")
                        .font(.headline)
                }

                GroupBox {
                    ConditionImmunityGrid(
                        immunities: Binding(
                            get: { npc.conditionImmunities },
                            set: { npc.conditionImmunities = $0 }
                        )
                    )
                } label: {
                    HStack(spacing: 8) {
                        Label("Condition Immunities", systemImage: "xmark.shield.fill")
                            .font(.headline)
                        if !npc.conditionImmunities.isEmpty {
                            Text("\(npc.conditionImmunities.count)")
                                .font(.caption.bold())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.18))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
        }
    }

    private func abilityScoreBinding(for ability: Ability) -> Binding<Int> {
        switch ability {
        case .strength: return $npc.strength
        case .dexterity: return $npc.dexterity
        case .constitution: return $npc.constitution
        case .intelligence: return $npc.intelligence
        case .wisdom: return $npc.wisdom
        case .charisma: return $npc.charisma
        }
    }
}

struct AddNPCSheet: View {
    let campaignID: UUID
    var onCreated: ((NPCTemplate) -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showJSONImport: Bool = false
    @State private var name: String = ""
    @State private var maxHP: Int = 20
    @State private var initiative: Int = 0
    @State private var armorClass: Int = 12
    @State private var speed: Int = 30
    @State private var flySpeed: Int = 0
    @State private var swimSpeed: Int = 0
    @State private var climbSpeed: Int = 0
    @State private var burrowSpeed: Int = 0
    @State private var canHover: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .trailing) {
                VStack(spacing: 6) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 32)).foregroundStyle(.green)
                    Text("Add NPC").font(.title2.bold())
                }
                .frame(maxWidth: .infinity)
                Button {
                    showJSONImport = true
                } label: {
                    Label("Import JSON", systemImage: "arrow.down.doc.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .padding(.trailing, 32)
            }
            .padding(.top, 24).padding(.bottom, 16)
            Divider()

            VStack(spacing: 16) {
                SheetFormRow(label: "Name") {
                    TextField("e.g. Town Guard", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                SheetFormRow(label: "Max HP") {
                    TextField("20", value: $maxHP, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                }
                SheetFormRow(label: "Initiative Bonus") {
                    TextField("0", value: $initiative, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                }
                SheetFormRow(label: "Armor Class") {
                    TextField("12", value: $armorClass, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                }
                SheetFormRow(label: "Walk Speed (ft)") {
                    TextField("30", value: $speed, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                }
                SheetFormRow(label: "Other Speeds (ft)") {
                    HStack(spacing: 8) {
                        VStack(spacing: 2) {
                            Text("Fly").font(.caption2).foregroundStyle(.secondary)
                            TextField("0", value: $flySpeed, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                                .frame(width: 54)
                        }
                        VStack(spacing: 2) {
                            Text("Swim").font(.caption2).foregroundStyle(.secondary)
                            TextField("0", value: $swimSpeed, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                                .frame(width: 54)
                        }
                        VStack(spacing: 2) {
                            Text("Climb").font(.caption2).foregroundStyle(.secondary)
                            TextField("0", value: $climbSpeed, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                                .frame(width: 54)
                        }
                        VStack(spacing: 2) {
                            Text("Burrow").font(.caption2).foregroundStyle(.secondary)
                            TextField("0", value: $burrowSpeed, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.center)
                                .frame(width: 54)
                        }
                    }
                }
                SheetFormRow(label: "Hovering") {
                    Toggle("", isOn: $canHover).labelsHidden().tint(.blue)
                }
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 24)
            Divider()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button("Add NPC") {
                    let npc = NPCTemplate(
                        name: name.isEmpty ? "New NPC" : name,
                        maxHP: max(1, maxHP),
                        initiative: initiative,
                        armorClass: max(1, armorClass),
                        campaignID: campaignID
                    )
                    npc.speed = max(0, speed)
                    npc.flySpeed = max(0, flySpeed)
                    npc.swimSpeed = max(0, swimSpeed)
                    npc.climbSpeed = max(0, climbSpeed)
                    npc.burrowSpeed = max(0, burrowSpeed)
                    npc.canHover = canHover
                    modelContext.insert(npc)
                    onCreated?(npc)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 480, height: 520)
        .sheet(isPresented: $showJSONImport) {
            NPCJSONImportSheet(campaignID: campaignID)
        }
    }
}

private struct NPCSpeedData: Decodable {
    var walk: Int?
    var fly: Int?
    var swim: Int?
    var climb: Int?
    var burrow: Int?
    var hover: Bool?
}

private struct NPCImportData: Decodable {
    var name: String
    var max_hp: String
    var initiative_bonus: Int?
    var armor_class: Int
    var speed: NPCSpeedData?
    var str: Int?
    var dex: Int?
    var con: Int?
    var intelligence: Int?
    var wis: Int?
    var cha: Int?
    var saving_throw_proficiencies: [String: Bool]?
    var damage_responses: [String: String]?
    var condition_immunities: [String]?

    enum CodingKeys: String, CodingKey {
        case name, max_hp, initiative_bonus, armor_class, speed
        case str, dex, con
        case intelligence = "int"
        case wis, cha
        case saving_throw_proficiencies, damage_responses, condition_immunities
    }
}

struct NPCJSONImportSheet: View {
    let campaignID: UUID
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var jsonText: String = ""
    @State private var errorMessage: String? = nil
    @State private var showFilePicker: Bool = false
    @State private var loadedFileName: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Import NPC from JSON", systemImage: "arrow.down.doc.fill")
                        .font(.title2.bold())
                    Text("Load a JSON file or paste the contents below")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showFilePicker = true
                } label: {
                    Label("Choose File…", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            if let fileName = loadedFileName {
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill").foregroundStyle(.green)
                    Text(fileName).font(.caption.bold()).foregroundStyle(.green)
                    Spacer()
                    Button {
                        jsonText = ""
                        loadedFileName = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 6)
            }

            TextEditor(text: $jsonText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
                .padding(6)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 24)
                .onChange(of: jsonText) { _, _ in errorMessage = nil }

            if let err = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            Spacer(minLength: 16)
            Divider()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button("Import") {
                    importJSON()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .keyboardShortcut(.defaultAction)
                .disabled(jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(20)
        }
        .frame(width: 540, height: 460)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    jsonText = content
                    loadedFileName = url.lastPathComponent
                    errorMessage = nil
                } catch {
                    errorMessage = "Could not read file: \(error.localizedDescription)"
                }
            case .failure(let error):
                errorMessage = "File picker error: \(error.localizedDescription)"
            }
        }
    }

    private func importJSON() {
        guard let data = jsonText.data(using: .utf8) else {
            errorMessage = "Invalid text encoding"
            return
        }
        do {
            let parsed = try JSONDecoder().decode(NPCImportData.self, from: data)

            let npc = NPCTemplate(
                name: parsed.name.isEmpty ? "Imported NPC" : parsed.name,
                maxHP: max(1, hpAverageFromFormula(parsed.max_hp)),
                hpFormula: parsed.max_hp,
                initiative: parsed.initiative_bonus ?? 0,
                armorClass: parsed.armor_class,
                campaignID: campaignID
            )
            npc.speed = parsed.speed?.walk ?? 30
            npc.flySpeed = parsed.speed?.fly ?? 0
            npc.swimSpeed = parsed.speed?.swim ?? 0
            npc.climbSpeed = parsed.speed?.climb ?? 0
            npc.burrowSpeed = parsed.speed?.burrow ?? 0
            npc.canHover = parsed.speed?.hover ?? false
            npc.strength = parsed.str ?? 10
            npc.dexterity = parsed.dex ?? 10
            npc.constitution = parsed.con ?? 10
            npc.intelligence = parsed.intelligence ?? 10
            npc.wisdom = parsed.wis ?? 10
            npc.charisma = parsed.cha ?? 10

            if let profs = parsed.saving_throw_proficiencies {
                var saveProfMap: [String: String] = [:]
                for (key, isProficient) in profs {
                    let abilityRaw = key.uppercased()
                    saveProfMap[abilityRaw] = isProficient
                        ? SaveProficiency.proficient.rawValue
                        : SaveProficiency.none.rawValue
                }
                npc.saveProficiencies = saveProfMap
            }

            if let dmgResponses = parsed.damage_responses {
                var responseMap: [String: String] = Dictionary(
                    uniqueKeysWithValues: DamageType.allCases.map { ($0.rawValue, DamageResponse.regular.rawValue) }
                )
                for (key, value) in dmgResponses {
                    let capitalizedKey = key.prefix(1).uppercased() + key.dropFirst()
                    if DamageType(rawValue: capitalizedKey) != nil {
                        let response = DamageResponse(rawValue: value) ?? .regular
                        responseMap[capitalizedKey] = response.rawValue
                    }
                }
                npc.damageResponses = responseMap
            }

            if let immunities = parsed.condition_immunities {
                npc.conditionImmunities = immunities.compactMap { raw in
                    let capitalized = raw.prefix(1).uppercased() + raw.dropFirst()
                    return ConditionType(rawValue: capitalized) != nil ? capitalized : nil
                }
            }

            modelContext.insert(npc)
            dismiss()
        } catch {
            errorMessage = "Parse error: \(error.localizedDescription)"
        }
    }
}
