import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BestiaryView: View {
    let campaign: Campaign
    @Bindable var sectionState: SectionState

    @Environment(\.modelContext) private var modelContext
    @Query private var templates: [MonsterTemplate]
    @State private var showAddSheet: Bool = false
    @State private var search = ""
    @State private var crFilter: String? = nil
    @State private var showDeleteConfirm = false

    init(campaign: Campaign, sectionState: SectionState) {
        self.campaign = campaign
        _sectionState = Bindable(sectionState)
        let cid = campaign.id
        _templates = Query(
            filter: #Predicate<MonsterTemplate> { t in t.isGlobal || t.campaignID == cid },
            sort: [SortDescriptor(\MonsterTemplate.name)]
        )
    }

    var filtered: [MonsterTemplate] {
        templates.filter { t in
            let matchesSearch = search.isEmpty || t.name.localizedCaseInsensitiveContains(search)
            let matchesCR = crFilter == nil || t.challengeRatingValue == crFilter
            return matchesSearch && matchesCR
        }
    }

    var availableCRs: [String] {
        Array(Set(templates.map { $0.challengeRatingValue }))
            .sorted { ChallengeRating(rawValue: $0)?.xp ?? 0 < ChallengeRating(rawValue: $1)?.xp ?? 0 }
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
                    Divider().frame(height: 14)
                    Menu {
                        Button("All CRs") { crFilter = nil }
                        Divider()
                        ForEach(availableCRs, id: \.self) { cr in
                            Button("CR \(cr)") { crFilter = (crFilter == cr) ? nil : cr }
                        }
                    } label: {
                        Image(systemName: crFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                            .foregroundStyle(crFilter == nil ? Color.secondary : Color.accentColor)
                            .font(.caption)
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                Divider()
                List(filtered, selection: $sectionState.selectedMonster) { template in
                    MonsterListRow(template: template).tag(template)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showAddSheet = true } label: { Label("Add Monster", systemImage: "plus") }
                    }
                    ToolbarItem {
                        Button { showDeleteConfirm = true } label: { Label("Delete", systemImage: "trash") }
                        .disabled(sectionState.selectedMonster == nil)
                    }
                }
            }
            .frame(minWidth: 230, maxWidth: 290)

            Divider()

            Group {
                if let template = sectionState.selectedMonster {
                    MonsterDetailView(template: template)
                } else {
                    ContentUnavailableView("No Monster Selected", systemImage: "book.closed",
                        description: Text("Select a monster template from the list or add a new one."))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Bestiary")
        .sheet(isPresented: $showAddSheet) { AddMonsterSheet(campaignID: campaign.id) }
        .alert("Delete Monster?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                guard let t = sectionState.selectedMonster else { return }
                modelContext.delete(t)
                sectionState.selectedMonster = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let t = sectionState.selectedMonster { Text("Delete '\(t.name)'? This cannot be undone.") }
        }
    }
}

struct MonsterListRow: View {
    let template: MonsterTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(template.name)
                    .font(.headline)
                if template.isGlobal {
                    Text("GLOBAL")
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.2))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())
                }
            }
            HStack(spacing: 10) {
                Label("HP \(template.maxHP)", systemImage: "heart.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                Label("AC \(template.armorClass)", systemImage: "shield.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Label("CR \(template.challengeRating.rawValue)", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("\(template.challengeRating.xp) XP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(template.initiative >= 0 ? "+\(template.initiative)" : "\(template.initiative)", systemImage: "dice")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct MonsterDetailView: View {
    @Bindable var template: MonsterTemplate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                GroupBox {
                    Form {
                        TextField("Name", text: $template.name, prompt: Text("Monster name"))
                        TextField("Max HP", value: $template.maxHP, format: .number, prompt: Text("30"))
                        TextField("Initiative Bonus", value: $template.initiative, format: .number, prompt: Text("0"))
                        TextField("Armor Class", value: $template.armorClass, format: .number, prompt: Text("13"))
                        TextField("Walk Speed (ft)", value: $template.speed, format: .number, prompt: Text("30"))
                        TextField("Fly Speed (ft, 0 = none)", value: $template.flySpeed, format: .number, prompt: Text("0"))
                        TextField("Swim Speed (ft, 0 = none)", value: $template.swimSpeed, format: .number, prompt: Text("0"))
                        TextField("Climb Speed (ft, 0 = none)", value: $template.climbSpeed, format: .number, prompt: Text("0"))
                        TextField("Burrow Speed (ft, 0 = none)", value: $template.burrowSpeed, format: .number, prompt: Text("0"))
                        Toggle("Hovering", isOn: $template.canHover)

                        LabeledContent("Challenge Rating") {
                            Picker("", selection: Binding(
                                get: { template.challengeRating },
                                set: { template.challengeRating = $0 }
                            )) {
                                ForEach(ChallengeRating.allCases) { cr in
                                    Text("CR \(cr.rawValue) (\(cr.xp) XP)").tag(cr)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 200)
                        }

                        LabeledContent("Scope") {
                            HStack(spacing: 8) {
                                Image(systemName: template.isGlobal ? "globe" : "scope")
                                    .foregroundStyle(template.isGlobal ? .purple : .blue)
                                Text(template.isGlobal ? "Global (all campaigns)" : "This campaign only")
                                    .font(.subheadline)
                                    .foregroundStyle(template.isGlobal ? .purple : .blue)
                                Toggle("", isOn: $template.isGlobal)
                                    .labelsHidden()
                                    .tint(.purple)
                            }
                        }
                    }
                    .formStyle(.grouped)
                } label: {
                    Label("Monster Info", systemImage: "flame.fill")
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
                                    Text(Combatant.formattedModifier(template.abilityScore(for: ability)))
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
                                        get: { template.saveProficiency(for: ability) },
                                        set: { template.setSaveProficiency($0, for: ability) }
                                    )
                                    let score = template.abilityScore(for: ability)
                                    let baseMod = Combatant.abilityModifier(score)
                                    let prof = template.saveProficiency(for: ability)
                                    let saveTotal = baseMod + template.challengeRating.proficiencyBonus * prof.multiplier

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
                            get: { template.damageResponses },
                            set: { template.damageResponses = $0 }
                        )
                    )
                } label: {
                    Label("Damage Responses", systemImage: "shield.lefthalf.filled")
                        .font(.headline)
                }

                GroupBox {
                    ConditionImmunityGrid(
                        immunities: Binding(
                            get: { template.conditionImmunities },
                            set: { template.conditionImmunities = $0 }
                        )
                    )
                } label: {
                    HStack(spacing: 8) {
                        Label("Condition Immunities", systemImage: "xmark.shield.fill")
                            .font(.headline)
                        if !template.conditionImmunities.isEmpty {
                            Text("\(template.conditionImmunities.count)")
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
        case .strength: return $template.strength
        case .dexterity: return $template.dexterity
        case .constitution: return $template.constitution
        case .intelligence: return $template.intelligence
        case .wisdom: return $template.wisdom
        case .charisma: return $template.charisma
        }
    }
}

struct AddMonsterSheet: View {
    let campaignID: UUID
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showJSONImport: Bool = false
    @State private var name: String = ""
    @State private var maxHP: Int = 30
    @State private var initiative: Int = 0
    @State private var armorClass: Int = 13
    @State private var speed: Int = 30
    @State private var flySpeed: Int = 0
    @State private var swimSpeed: Int = 0
    @State private var climbSpeed: Int = 0
    @State private var burrowSpeed: Int = 0
    @State private var canHover: Bool = false
    @State private var challengeRating: ChallengeRating = .zero
    @State private var isGlobal: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .trailing) {
                VStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 32)).foregroundStyle(.red)
                    Text("Add Monster Template").font(.title2.bold())
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
                BestiaryFormRow(label: "Name") {
                    TextField("e.g. Goblin", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                BestiaryFormRow(label: "Max HP") {
                    TextField("30", value: $maxHP, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                }
                BestiaryFormRow(label: "Initiative Bonus") {
                    TextField("0", value: $initiative, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                }
                BestiaryFormRow(label: "Armor Class") {
                    TextField("13", value: $armorClass, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                }
                BestiaryFormRow(label: "Walk Speed (ft)") {
                    TextField("30", value: $speed, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                }
                BestiaryFormRow(label: "Other Speeds (ft)") {
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
                BestiaryFormRow(label: "Hovering") {
                    Toggle("", isOn: $canHover).labelsHidden().tint(.blue)
                }
                BestiaryFormRow(label: "Challenge Rating") {
                    Picker("", selection: $challengeRating) {
                        ForEach(ChallengeRating.allCases) { cr in
                            Text("CR \(cr.rawValue) — \(cr.xp) XP").tag(cr)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
                BestiaryFormRow(label: "Global Monster") {
                    HStack(spacing: 8) {
                        Toggle("", isOn: $isGlobal)
                            .labelsHidden()
                            .tint(.purple)
                        Text(isGlobal ? "Available in all campaigns" : "This campaign only")
                            .font(.caption)
                            .foregroundStyle(isGlobal ? .purple : .secondary)
                    }
                }
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 24)
            Divider()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button("Add Monster") {
                    let t = MonsterTemplate(
                        name: name.isEmpty ? "New Monster" : name,
                        maxHP: max(1, maxHP),
                        initiative: initiative,
                        armorClass: max(1, armorClass),
                        campaignID: campaignID,
                        isGlobal: isGlobal
                    )
                    t.challengeRatingValue = challengeRating.rawValue
                    t.speed = max(0, speed)
                    t.flySpeed = max(0, flySpeed)
                    t.swimSpeed = max(0, swimSpeed)
                    t.climbSpeed = max(0, climbSpeed)
                    t.burrowSpeed = max(0, burrowSpeed)
                    t.canHover = canHover
                    modelContext.insert(t)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 500, height: 560)
        .sheet(isPresented: $showJSONImport) {
            MonsterJSONImportSheet(campaignID: campaignID)
        }
    }
}

private struct SpeedData: Decodable {
    var walk: Int?
    var fly: Int?
    var swim: Int?
    var climb: Int?
    var burrow: Int?
    var hover: Bool?
}

private struct MonsterImportData: Decodable {
    var name: String
    var max_hp: String
    var initiative_bonus: Int?
    var armor_class: Int
    var challenge_rating: String
    var speed: SpeedData?
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
        case name, max_hp, initiative_bonus, armor_class, challenge_rating
        case speed, str, dex, con
        case intelligence = "int"
        case wis, cha
        case saving_throw_proficiencies, damage_responses, condition_immunities
    }
}

func hpAverageFromFormula(_ formula: String) -> Int {
    let clean = formula.replacingOccurrences(of: " ", with: "")
    if let fixed = Int(clean) { return max(1, fixed) }
    guard let match = clean.range(of: #"(\d+)d(\d+)([+-]\d+)?"#, options: .regularExpression) else { return 1 }
    let part = String(clean[match])
    let nums = part.components(separatedBy: CharacterSet(charactersIn: "d+-"))
        .compactMap { Int($0) }
    guard nums.count >= 2 else { return 1 }
    let count = nums[0], sides = nums[1]
    let mod: Int = {
        if let plusIdx = part.firstIndex(of: "+") {
            return Int(part[part.index(after: plusIdx)...]) ?? 0
        } else if let minusIdx = part.dropFirst().firstIndex(of: "-") {
            return -(Int(part[part.index(after: minusIdx)...]) ?? 0)
        }
        return 0
    }()
    return max(1, count * (sides + 1) / 2 + mod)
}

func hpRollFromFormula(_ formula: String) -> Int {
    let clean = formula.replacingOccurrences(of: " ", with: "")
    if let fixed = Int(clean) { return max(1, fixed) }
    guard let match = clean.range(of: #"(\d+)d(\d+)([+-]\d+)?"#, options: .regularExpression) else { return 1 }
    let part = String(clean[match])
    let nums = part.components(separatedBy: CharacterSet(charactersIn: "d+-"))
        .compactMap { Int($0) }
    guard nums.count >= 2 else { return 1 }
    let count = nums[0], sides = nums[1]
    let mod: Int = {
        if let plusIdx = part.firstIndex(of: "+") {
            return Int(part[part.index(after: plusIdx)...]) ?? 0
        } else if let minusIdx = part.dropFirst().firstIndex(of: "-") {
            return -(Int(part[part.index(after: minusIdx)...]) ?? 0)
        }
        return 0
    }()
    let rolled = (0..<count).reduce(0) { acc, _ in acc + Int.random(in: 1...max(1, sides)) }
    return max(1, rolled + mod)
}

struct MonsterJSONImportSheet: View {
    let campaignID: UUID
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var jsonText: String = ""
    @State private var errorMessage: String? = nil
    @State private var isGlobal: Bool = false
    @State private var showFilePicker: Bool = false
    @State private var parsedMonsters: [MonsterImportData] = []

    private var canImport: Bool {
        !parsedMonsters.isEmpty || !jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var importButtonTitle: String {
        parsedMonsters.isEmpty ? "Import" : "Import \(parsedMonsters.count) Monster\(parsedMonsters.count == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Import from JSON", systemImage: "arrow.down.doc.fill")
                        .font(.title2.bold())
                    Text("Load one or more JSON files, or paste JSON below")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showFilePicker = true
                } label: {
                    Label("Choose Files…", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            if !parsedMonsters.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("\(parsedMonsters.count) monster\(parsedMonsters.count == 1 ? "" : "s") ready to import")
                            .font(.caption.bold()).foregroundStyle(.green)
                        Spacer()
                        Button {
                            parsedMonsters = []
                            jsonText = ""
                            errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(parsedMonsters, id: \.name) { m in
                                Text(m.name)
                                    .font(.caption2)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
            } else {
                TextEditor(text: $jsonText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .padding(6)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 24)
                    .onChange(of: jsonText) { _, _ in errorMessage = nil }
            }

            if let err = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            HStack(spacing: 10) {
                Toggle("", isOn: $isGlobal).labelsHidden().tint(.purple)
                Text(isGlobal ? "Global monster (all campaigns)" : "This campaign only")
                    .font(.caption)
                    .foregroundStyle(isGlobal ? .purple : .secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer(minLength: 16)
            Divider()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button(importButtonTitle) {
                    performImport()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .keyboardShortcut(.defaultAction)
                .disabled(!canImport)
            }
            .padding(20)
        }
        .frame(width: 540, height: 420)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                var loaded: [MonsterImportData] = []
                var errors: [String] = []
                for url in urls {
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    guard let data = try? Data(contentsOf: url) else {
                        errors.append("Could not read \(url.lastPathComponent)")
                        continue
                    }
                    if let single = try? JSONDecoder().decode(MonsterImportData.self, from: data) {
                        loaded.append(single)
                    } else if let array = try? JSONDecoder().decode([MonsterImportData].self, from: data) {
                        loaded.append(contentsOf: array)
                    } else {
                        errors.append("Invalid JSON in \(url.lastPathComponent)")
                    }
                }
                parsedMonsters = loaded
                jsonText = ""
                errorMessage = errors.isEmpty ? nil : errors.joined(separator: "\n")
            case .failure(let error):
                errorMessage = "File picker error: \(error.localizedDescription)"
            }
        }
    }

    private func performImport() {
        if !parsedMonsters.isEmpty {
            parsedMonsters.forEach { insertMonster($0) }
            dismiss()
        } else {
            guard let data = jsonText.data(using: .utf8) else {
                errorMessage = "Invalid text encoding"
                return
            }
            if let single = try? JSONDecoder().decode(MonsterImportData.self, from: data) {
                insertMonster(single)
                dismiss()
            } else if let array = try? JSONDecoder().decode([MonsterImportData].self, from: data) {
                if array.isEmpty { errorMessage = "No monsters found in JSON"; return }
                array.forEach { insertMonster($0) }
                dismiss()
            } else {
                errorMessage = "Parse error: JSON must be a monster object or array of monster objects"
            }
        }
    }

    private func insertMonster(_ parsed: MonsterImportData) {
        let avgHP = hpAverageFromFormula(parsed.max_hp)
        let cr = ChallengeRating(rawValue: parsed.challenge_rating) ?? .zero
        let t = MonsterTemplate(
            name: parsed.name.isEmpty ? "Imported Monster" : parsed.name,
            maxHP: avgHP,
            hpFormula: parsed.max_hp,
            initiative: parsed.initiative_bonus ?? 0,
            armorClass: parsed.armor_class,
            campaignID: campaignID,
            isGlobal: isGlobal
        )
        t.challengeRatingValue = cr.rawValue
        t.speed = parsed.speed?.walk ?? 30
        t.flySpeed = parsed.speed?.fly ?? 0
        t.swimSpeed = parsed.speed?.swim ?? 0
        t.climbSpeed = parsed.speed?.climb ?? 0
        t.burrowSpeed = parsed.speed?.burrow ?? 0
        t.canHover = parsed.speed?.hover ?? false
        t.strength = parsed.str ?? 10
        t.dexterity = parsed.dex ?? 10
        t.constitution = parsed.con ?? 10
        t.intelligence = parsed.intelligence ?? 10
        t.wisdom = parsed.wis ?? 10
        t.charisma = parsed.cha ?? 10
        if let profs = parsed.saving_throw_proficiencies {
            var saveProfMap: [String: String] = [:]
            for (key, isProficient) in profs {
                saveProfMap[key.uppercased()] = isProficient ? SaveProficiency.proficient.rawValue : SaveProficiency.none.rawValue
            }
            t.saveProficiencies = saveProfMap
        }
        if let dmgResponses = parsed.damage_responses {
            var responseMap: [String: String] = Dictionary(
                uniqueKeysWithValues: DamageType.allCases.map { ($0.rawValue, DamageResponse.regular.rawValue) }
            )
            for (key, value) in dmgResponses {
                let cap = key.prefix(1).uppercased() + key.dropFirst()
                if DamageType(rawValue: cap) != nil {
                    responseMap[cap] = (DamageResponse(rawValue: value) ?? .regular).rawValue
                }
            }
            t.damageResponses = responseMap
        }
        if let immunities = parsed.condition_immunities {
            t.conditionImmunities = immunities.compactMap { raw in
                let cap = raw.prefix(1).uppercased() + raw.dropFirst()
                return ConditionType(rawValue: cap) != nil ? cap : nil
            }
        }
        modelContext.insert(t)
    }
}

struct BestiaryFormRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 16) {
            Text(label)
                .font(.callout.bold())
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .trailing)
            content()
            Spacer()
        }
    }
}
