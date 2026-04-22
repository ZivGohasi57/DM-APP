import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PCLibraryView: View {
    let campaign: Campaign
    @Bindable var sectionState: SectionState

    @Environment(\.modelContext) private var modelContext
    @Query private var characters: [PlayerCharacter]
    @State private var showAddSheet: Bool = false
    @State private var search = ""
    @State private var showDeleteConfirm = false

    init(campaign: Campaign, sectionState: SectionState) {
        self.campaign = campaign
        _sectionState = Bindable(sectionState)
        let cid = campaign.id
        _characters = Query(
            filter: #Predicate<PlayerCharacter> { $0.campaignID == cid },
            sort: [SortDescriptor(\PlayerCharacter.name)]
        )
    }

    var filtered: [PlayerCharacter] {
        search.isEmpty ? characters : characters.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.playerName.localizedCaseInsensitiveContains(search) }
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
                List(filtered, selection: $sectionState.selectedPC) { pc in
                    PCListRow(pc: pc).tag(pc)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showAddSheet = true } label: { Label("Add Character", systemImage: "plus") }
                    }
                    ToolbarItem {
                        Button { showDeleteConfirm = true } label: { Label("Delete", systemImage: "trash") }
                        .disabled(sectionState.selectedPC == nil)
                    }
                }
            }
            .frame(minWidth: 230, maxWidth: 290)

            Divider()

            Group {
                if let pc = sectionState.selectedPC {
                    PCDetailView(pc: pc, campaign: campaign)
                } else {
                    ContentUnavailableView("No Character Selected", systemImage: "person.2",
                        description: Text("Select a character from the list or add a new one."))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("PC Library")
        .sheet(isPresented: $showAddSheet) { AddPCSheet(campaignID: campaign.id) }
        .alert("Delete Character?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                guard let pc = sectionState.selectedPC else { return }
                modelContext.delete(pc)
                sectionState.selectedPC = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let pc = sectionState.selectedPC { Text("Delete '\(pc.name)'? This cannot be undone.") }
        }
    }
}

struct PCListRow: View {
    let pc: PlayerCharacter

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(pc.displayName)
                    .font(.headline)
                Spacer()
                Text("Lv \(pc.level)")
                    .font(.caption.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.18))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
            HStack(spacing: 10) {
                Label("\(pc.currentHP)/\(pc.maxHP)", systemImage: "heart.fill")
                    .font(.subheadline)
                    .foregroundStyle(hpColor)
                Label("AC \(pc.armorClass)", systemImage: "shield.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                let totalCP = pc.gold * 100 + pc.silver * 10 + pc.copper
                if totalCP > 0 {
                    let displayGP = totalCP / 100
                    let displaySP = (totalCP % 100) / 10
                    let displayCP = totalCP % 10
                    Label(displaySP == 0 && displayCP == 0 ? "\(displayGP) gp" : "\(displayGP) gp \(displaySP) sp \(displayCP) cp",
                          systemImage: "dollarsign.circle")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
            if let nextLevelXP = pc.xpForNextLevel {
                let currentLevelXP = ChallengeRating.xpForLevel(pc.level)
                let rangeXP = nextLevelXP - currentLevelXP
                let gainedXP = pc.currentXP - currentLevelXP
                HStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 4)
                            Capsule()
                                .fill(Color.blue.opacity(0.7))
                                .frame(width: max(0, geo.size.width * pc.xpProgressInCurrentLevel), height: 4)
                        }
                    }
                    .frame(height: 4)
                    Text("\(gainedXP)/\(rangeXP) XP")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } else {
                Text("\(pc.currentXP) XP — Max Level")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 7)
    }

    var hpColor: Color {
        let pct = Double(pc.currentHP) / Double(max(1, pc.maxHP))
        if pct > 0.5 { return .green }
        if pct > 0.25 { return .yellow }
        if pct > 0 { return .red }
        return .gray
    }
}

struct PCDetailView: View {
    @Bindable var pc: PlayerCharacter
    let campaign: Campaign
    @State private var showAddResource: Bool = false
    @State private var showShortRest: Bool = false
    @State private var showAddAltForm: Bool = false
    @State private var showAddItem: Bool = false
    @State private var showWishlist: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                GroupBox {
                    Form {
                        TextField("Character Name", text: $pc.name, prompt: Text("e.g. Aragorn"))
                        TextField("Player Name", text: $pc.playerName, prompt: Text("e.g. John"))
                        TextField("Max HP", value: $pc.maxHP, format: .number, prompt: Text("20"))
                        LabeledContent("Current HP") {
                            HStack(spacing: 8) {
                                TextField("", value: $pc.currentHP, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                Button("Reset") { pc.currentHP = pc.maxHP }
                                    .buttonStyle(.borderless)
                                    .controlSize(.small)
                            }
                        }
                        TextField("Armor Class", value: $pc.armorClass, format: .number, prompt: Text("14"))
                        TextField("Strength (STR)", value: $pc.strength, format: .number, prompt: Text("10"))
                        TextField("Base Speed (ft)", value: $pc.baseSpeed, format: .number, prompt: Text("30"))
                        TextField("Fly Speed (ft, 0 = none)", value: $pc.flySpeed, format: .number, prompt: Text("0"))
                        TextField("Swim Speed (ft, 0 = none)", value: $pc.swimSpeed, format: .number, prompt: Text("0"))
                        TextField("Climb Speed (ft, 0 = none)", value: $pc.climbSpeed, format: .number, prompt: Text("0"))
                        TextField("Burrow Speed (ft, 0 = none)", value: $pc.burrowSpeed, format: .number, prompt: Text("0"))
                        TextField("Passive Perception", value: $pc.passivePerception, format: .number, prompt: Text("10"))
                        TextField("Passive Insight", value: $pc.passiveInsight, format: .number, prompt: Text("10"))
                        TextField("Passive Investigation", value: $pc.passiveInvestigation, format: .number, prompt: Text("10"))
                        TextField("Darkvision (ft, 0 = none)", value: $pc.darkvisionRange, format: .number, prompt: Text("0"))
                        LabeledContent("Size") {
                            Picker("", selection: Binding(
                                get: { pc.size },
                                set: { pc.size = $0 }
                            )) {
                                ForEach(CreatureSize.allCases) { s in
                                    Text(s.rawValue).tag(s)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 160)
                        }
                    }
                    .formStyle(.grouped)
                } label: {
                    Label("Character Info", systemImage: "person.fill")
                        .font(.headline)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.circle.fill").foregroundStyle(.blue)
                                    Text("Level").font(.subheadline.bold())
                                }
                                HStack(spacing: 8) {
                                    Stepper("", value: $pc.level, in: 1...20)
                                        .labelsHidden()
                                    Text("\(pc.level)")
                                        .font(.title2.bold())
                                        .frame(width: 28)
                                }
                            }

                            Divider().frame(height: 48)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles").foregroundStyle(.purple)
                                    Text("Current XP").font(.subheadline.bold())
                                }
                                TextField("XP", value: $pc.currentXP, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 110)
                            }

                            Spacer()

                            if let nextXP = pc.xpForNextLevel {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Next Level")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(nextXP - pc.currentXP) XP needed")
                                        .font(.caption.bold())
                                        .foregroundStyle(.purple)
                                    ProgressView(value: pc.xpProgressInCurrentLevel)
                                        .frame(width: 100)
                                        .tint(.purple)
                                }
                            } else {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Image(systemName: "crown.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.title2)
                                    Text("Max Level")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                } label: {
                    Label("Level & Experience", systemImage: "star.circle.fill")
                        .font(.headline)
                }

                GroupBox {
                    GoldDeltaField(pc: pc)
                } label: {
                    Label("Wealth", systemImage: "dollarsign.circle.fill")
                        .font(.headline)
                }

                GroupBox {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Spacer()
                            Button {
                                showShortRest = true
                            } label: {
                                Label("Short Rest", systemImage: "moon.fill")
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)

                            Button {
                                applyLongRest()
                            } label: {
                                Label("Long Rest", systemImage: "moon.stars.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.indigo)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 4)

                        Divider()

                        if pc.resources.isEmpty {
                            Text("No resources defined. Add spell slots, ki points, or any trackable resource.")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .padding(16)
                        } else {
                            ForEach(pc.resources) { resource in
                                PCResourceRow(pc: pc, resource: resource)
                                Divider()
                            }
                        }
                        Button {
                            showAddResource = true
                        } label: {
                            Label("Add Resource", systemImage: "plus.circle")
                        }
                        .padding(12)
                    }
                } label: {
                    Label("Resources", systemImage: "bolt.circle.fill")
                        .font(.headline)
                }
                .sheet(isPresented: $showAddResource) {
                    AddResourceSheet(pc: pc)
                }
                .sheet(isPresented: $showShortRest) {
                    ShortRestSheet(pc: pc)
                }

                GroupBox {
                    VStack(spacing: 0) {
                        if pc.altForms.isEmpty {
                            Text("No alternate forms defined.")
                                .font(.subheadline).foregroundStyle(.tertiary)
                                .padding(14)
                        } else {
                            ForEach(pc.altForms) { form in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "figure.stand")
                                            .foregroundStyle(.purple)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(form.name).font(.subheadline.bold())
                                            HStack(spacing: 8) {
                                                if !form.isLinked {
                                                    Label("\(form.maxHP) HP", systemImage: "heart.fill")
                                                        .font(.caption).foregroundStyle(.red)
                                                }
                                                Label("AC \(form.armorClass)", systemImage: "shield.fill")
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Picker("", selection: Binding(
                                            get: { form.isLinked },
                                            set: { newVal in
                                                var forms = pc.altForms
                                                if let idx = forms.firstIndex(where: { $0.id == form.id }) {
                                                    forms[idx].isLinked = newVal
                                                }
                                                pc.altForms = forms
                                            }
                                        )) {
                                            Label("Separate", systemImage: "person.fill").tag(false)
                                            Label("Linked HP", systemImage: "link").tag(true)
                                        }
                                        .pickerStyle(.segmented)
                                        .frame(width: 180)
                                        .help("Separate: own HP pool. Linked: shares HP with base form.")
                                        Button {
                                            var forms = pc.altForms
                                            forms.removeAll { $0.id == form.id }
                                            pc.altForms = forms
                                        } label: {
                                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 10).padding(.horizontal, 12)
                                Divider()
                            }
                        }
                        Button { showAddAltForm = true } label: {
                            Label("Add Alternate Form", systemImage: "plus.circle")
                        }
                        .padding(12)
                    }
                } label: {
                    Label("Alternate Forms", systemImage: "figure.stand")
                        .font(.headline)
                }
                .sheet(isPresented: $showAddAltForm) {
                    AddAltFormSheet(pc: pc)
                }

                GroupBox {
                    PCCombatSymbolPicker(pc: pc)
                } label: {
                    HStack(spacing: 8) {
                        Label("Combat Symbol", systemImage: "crown.fill")
                            .font(.headline)
                        if !pc.combatSymbol.isEmpty {
                            Text(pc.combatSymbol)
                                .font(.subheadline.bold())
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                GroupBox {
                    DamageResponseGrid(
                        responses: Binding(
                            get: { pc.damageResponses },
                            set: { pc.damageResponses = $0 }
                        )
                    )
                } label: {
                    Label("Damage Responses", systemImage: "shield.lefthalf.filled")
                        .font(.headline)
                }

                GroupBox {
                    ConditionImmunityGrid(
                        immunities: Binding(
                            get: { pc.conditionImmunities },
                            set: { pc.conditionImmunities = $0 }
                        )
                    )
                } label: {
                    HStack(spacing: 8) {
                        Label("Condition Immunities", systemImage: "xmark.shield.fill")
                            .font(.headline)
                        if !pc.conditionImmunities.isEmpty {
                            Text("\(pc.conditionImmunities.count)")
                                .font(.caption.bold())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.18))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        }
                    }
                }

                GroupBox {
                    InventorySection(pc: pc, showAddItem: $showAddItem)
                } label: {
                    HStack(spacing: 8) {
                        Label("Inventory", systemImage: "backpack.fill")
                            .font(.headline)
                        let pct = pc.maxCarryWeight > 0 ? pc.currentCarryWeight / pc.maxCarryWeight : 0
                        if pct > 1 {
                            Text("OVER")
                                .font(.caption.bold())
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Color.red.opacity(0.2))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        } else if !pc.inventory.isEmpty {
                            Text(String(format: "%.1f / %.0f lbs", pc.currentCarryWeight, pc.maxCarryWeight))
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .sheet(isPresented: $showAddItem) {
                    AddItemSheet(pc: pc)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Track items \(pc.name) wants to find or buy across the world.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button {
                            showWishlist = true
                        } label: {
                            Label("Open Wishlist", systemImage: "heart.circle.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Wishlist", systemImage: "heart.circle.fill")
                        .font(.headline)
                }
                .sheet(isPresented: $showWishlist) {
                    PCWishlistView(pc: pc, campaign: campaign)
                }

                Spacer()
            }
            .padding(20)
        }
    }

    private func applyLongRest() {
        pc.currentHP = pc.maxHP
        var rs = pc.resources
        for i in rs.indices { rs[i].currentValue = rs[i].maxValue }
        pc.resources = rs
    }
}

struct ShortRestSheet: View {
    @Bindable var pc: PlayerCharacter
    @Environment(\.dismiss) private var dismiss
    @State private var hpText: String = ""

    var shortRestResources: [CharacterResource] {
        pc.resources.filter { $0.restType == .shortRest }
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
                Text("Short Rest")
                    .font(.title2.bold())
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Hit Dice Recovery")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    TextField("HP to recover", text: $hpText, prompt: Text("0"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                    Text("HP")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            if !shortRestResources.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Short Rest resources restored:")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    ForEach(shortRestResources) { resource in
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.caption)
                            Text(resource.name)
                                .font(.subheadline)
                            Spacer()
                            Text("\(resource.currentValue) → \(resource.maxValue)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color.blue.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("No short rest resources defined.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button("Take Short Rest") {
                    applyShortRest()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 400)
    }

    private func applyShortRest() {
        if let hp = Int(hpText), hp > 0 {
            pc.currentHP = min(pc.maxHP, pc.currentHP + hp)
        }
        var rs = pc.resources
        for i in rs.indices where rs[i].restType == .shortRest {
            rs[i].currentValue = rs[i].maxValue
        }
        pc.resources = rs
        dismiss()
    }
}

struct PCResourceRow: View {
    @Bindable var pc: PlayerCharacter
    let resource: CharacterResource

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(resource.name)
                    .font(.subheadline.bold())
                Text(resource.restType.rawValue)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(resource.restType == .longRest ? Color.indigo.opacity(0.18) : Color.blue.opacity(0.18))
                    .foregroundStyle(resource.restType == .longRest ? .indigo : .blue)
                    .clipShape(Capsule())
            }

            Spacer()

            Button {
                var rs = pc.resources
                if let idx = rs.firstIndex(where: { $0.id == resource.id }) {
                    rs[idx].currentValue = max(0, rs[idx].currentValue - 1)
                }
                pc.resources = rs
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(resource.currentValue > 0 ? Color.red : Color.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(resource.currentValue <= 0)

            Text("\(resource.currentValue) / \(resource.maxValue)")
                .font(.subheadline.monospacedDigit())
                .frame(width: 64, alignment: .center)

            Button {
                var rs = pc.resources
                if let idx = rs.firstIndex(where: { $0.id == resource.id }) {
                    rs[idx].currentValue = min(rs[idx].maxValue, rs[idx].currentValue + 1)
                }
                pc.resources = rs
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(resource.currentValue < resource.maxValue ? Color.green : Color.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(resource.currentValue >= resource.maxValue)

            Button {
                var rs = pc.resources
                if let idx = rs.firstIndex(where: { $0.id == resource.id }) {
                    rs[idx].currentValue = rs[idx].maxValue
                }
                pc.resources = rs
            } label: {
                Image(systemName: "arrow.counterclockwise.circle")
                    .foregroundStyle(.blue)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Restore to max")

            Button {
                var rs = pc.resources
                rs.removeAll { $0.id == resource.id }
                pc.resources = rs
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Delete resource")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

struct GoldDeltaField: View {
    @Bindable var pc: PlayerCharacter
    @FocusState private var txFocused: Bool
    @State private var amountText: String = ""
    @State private var denomination: CoinType = .gold

    @State private var gpText: String = ""
    @State private var spText: String = ""
    @State private var cpText: String = ""
    @FocusState private var gpFocused: Bool
    @FocusState private var spFocused: Bool
    @FocusState private var cpFocused: Bool

    enum CoinType: String, CaseIterable {
        case gold = "GP"; case silver = "SP"; case copper = "CP"
        var color: Color {
            switch self {
            case .gold:   return .yellow
            case .silver: return Color(white: 0.75)
            case .copper: return Color(red: 0.8, green: 0.5, blue: 0.2)
            }
        }
        var toCPMultiplier: Int {
            switch self { case .gold: return 100; case .silver: return 10; case .copper: return 1 }
        }
    }

    private var totalCP: Int { pc.gold * 100 + pc.silver * 10 + pc.copper }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 0) {
                coinEditBox(label: "GP", color: .yellow, icon: "dollarsign.circle.fill", text: $gpText, focused: $gpFocused)
                Divider().frame(height: 44)
                coinEditBox(label: "SP", color: Color(white: 0.75), icon: "circle.fill", text: $spText, focused: $spFocused)
                Divider().frame(height: 44)
                coinEditBox(label: "CP", color: Color(red: 0.8, green: 0.5, blue: 0.2), icon: "circle.fill", text: $cpText, focused: $cpFocused)
            }
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Divider()

            HStack(spacing: 10) {
                TextField("Amount", text: $amountText)
                    .focused($txFocused)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .multilineTextAlignment(.center)
                    .onSubmit { apply(sign: 1) }

                Picker("", selection: $denomination) {
                    ForEach(CoinType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)

                Spacer()

                Button { apply(sign: -1) } label: {
                    Image(systemName: "minus.circle.fill").font(.title2).foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .disabled(amountText.isEmpty || Int(amountText) == nil)

                Button { apply(sign: 1) } label: {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .disabled(amountText.isEmpty || Int(amountText) == nil)
            }
        }
        .padding(14)
        .onAppear { syncTexts() }
        .onChange(of: totalCP) { _, _ in
            if !gpFocused { gpText = "\(totalCP / 100)" }
            if !spFocused { spText = "\(totalCP / 10)" }
            if !cpFocused { cpText = "\(totalCP)" }
        }
    }

    @ViewBuilder
    private func coinEditBox(label: String, color: Color, icon: String, text: Binding<String>, focused: FocusState<Bool>.Binding) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color).font(.title3)
            TextField("0", text: text)
                .focused(focused)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .font(.title2.monospacedDigit().bold())
                .frame(width: 80)
                .onChange(of: focused.wrappedValue) { _, isFocused in
                    if isFocused {
                        text.wrappedValue = ""
                    } else {
                        commitField(label: label, text: text.wrappedValue)
                        syncTexts()
                    }
                }
                .onSubmit {
                    commitField(label: label, text: text.wrappedValue)
                    syncTexts()
                    focused.wrappedValue = false
                }
            Text(label).font(.caption2.bold()).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private func commitField(label: String, text: String) {
        guard let v = Int(text), v >= 0 else { return }
        switch label {
        case "GP": setTotal(v * 100)
        case "SP": setTotal(v * 10)
        default:   setTotal(v)
        }
    }

    private func syncTexts() {
        if !gpFocused { gpText = "\(totalCP / 100)" }
        if !spFocused { spText = "\(totalCP / 10)" }
        if !cpFocused { cpText = "\(totalCP)" }
    }

    private func setTotal(_ newTotalCP: Int) {
        let t = max(0, newTotalCP)
        pc.gold   = t / 100
        pc.silver = (t % 100) / 10
        pc.copper = t % 10
    }

    private func apply(sign: Int) {
        guard let amount = Int(amountText), amount > 0 else { return }
        setTotal(totalCP + sign * amount * denomination.toCPMultiplier)
        amountText = ""
        txFocused = false
    }
}

struct AddResourceSheet: View {
    @Bindable var pc: PlayerCharacter
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var maxValue: Int = 4
    @State private var currentValue: Int = 4
    @State private var restType: RestType = .longRest
    @State private var requiresConcentration: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 32)).foregroundStyle(.purple)
                Text("Add Resource").font(.title2.bold())
            }
            .padding(.top, 24).padding(.bottom, 16)
            Divider()

            VStack(spacing: 16) {
                SheetFormRow(label: "Name") {
                    TextField("e.g. Level 1 Spell Slots", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                SheetFormRow(label: "Maximum") {
                    TextField("4", value: $maxValue, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                }
                SheetFormRow(label: "Current") {
                    TextField("4", value: $currentValue, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                }
                SheetFormRow(label: "Recharges On") {
                    Picker("", selection: $restType) {
                        ForEach(RestType.allCases) { rt in
                            Text(rt.rawValue).tag(rt)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }
                SheetFormRow(label: "Concentration") {
                    Toggle("Requires concentration", isOn: $requiresConcentration)
                        .toggleStyle(.checkbox)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 24)
            Divider()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    let safeMax = max(1, maxValue)
                    let safeCurrent = max(0, min(safeMax, currentValue))
                    var rs = pc.resources
                    rs.append(CharacterResource(
                        name: name.isEmpty ? "Resource" : name,
                        maxValue: safeMax,
                        currentValue: safeCurrent,
                        restType: restType,
                        requiresConcentration: requiresConcentration
                    ))
                    pc.resources = rs
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 420, height: 340)
    }
}

struct AddPCSheet: View {
    let campaignID: UUID
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var playerName: String = ""
    @State private var maxHP: Int = 20
    @State private var armorClass: Int = 14
    @State private var level: Int = 1

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 32)).foregroundStyle(.blue)
                Text("Add Player Character").font(.title2.bold())
            }
            .padding(.top, 24).padding(.bottom, 16)
            Divider()

            VStack(spacing: 16) {
                SheetFormRow(label: "Character Name") {
                    TextField("e.g. Aragorn", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                SheetFormRow(label: "Player Name") {
                    TextField("e.g. John", text: $playerName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                SheetFormRow(label: "Max HP") {
                    TextField("20", value: $maxHP, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                }
                SheetFormRow(label: "Armor Class") {
                    TextField("14", value: $armorClass, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                }
                SheetFormRow(label: "Starting Level") {
                    HStack(spacing: 10) {
                        Stepper("", value: $level, in: 1...20).labelsHidden()
                        Text("\(level)")
                            .font(.headline.bold())
                            .frame(width: 28, alignment: .center)
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
                Button("Add Character") {
                    let pc = PlayerCharacter(
                        name: name.isEmpty ? "New Character" : name,
                        playerName: playerName,
                        maxHP: max(1, maxHP),
                        armorClass: max(1, armorClass),
                        campaignID: campaignID
                    )
                    pc.level = level
                    pc.currentXP = ChallengeRating.xpForLevel(level)
                    modelContext.insert(pc)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 420, height: 370)
    }
}

struct PCCombatSymbolPicker: View {
    @Bindable var pc: PlayerCharacter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Assigned automatically as nickname when this character enters combat.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(whitePieces, id: \.self) { piece in
                        ChessPieceButton(piece: piece, isSelected: pc.combatSymbol == piece, isWhite: true) {
                            pc.combatSymbol = pc.combatSymbol == piece ? "" : piece
                        }
                    }
                    Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 1, height: 22)
                    ForEach(blackPieces, id: \.self) { piece in
                        ChessPieceButton(piece: piece, isSelected: pc.combatSymbol == piece, isWhite: false) {
                            pc.combatSymbol = pc.combatSymbol == piece ? "" : piece
                        }
                    }
                    Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 1, height: 22)
                    TextField("Custom", text: Binding(
                        get: { allChessPieces.contains(pc.combatSymbol) ? "" : pc.combatSymbol },
                        set: { pc.combatSymbol = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .font(.caption)

                    if !pc.combatSymbol.isEmpty {
                        Button {
                            pc.combatSymbol = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear symbol")
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct AddAltFormSheet: View {
    @Bindable var pc: PlayerCharacter
    @Environment(\.dismiss) private var dismiss
    @State private var showJSONImport: Bool = false
    @State private var name: String = ""
    @State private var maxHP: Int = 30
    @State private var armorClass: Int = 10
    @State private var initiative: Int = 0
    @State private var speed: Int = 30
    @State private var flySpeed: Int = 0
    @State private var swimSpeed: Int = 0
    @State private var climbSpeed: Int = 0
    @State private var burrowSpeed: Int = 0
    @State private var canHover: Bool = false
    @State private var strength: Int = 10
    @State private var dexterity: Int = 10
    @State private var constitution: Int = 10
    @State private var intelligence: Int = 10
    @State private var wisdom: Int = 10
    @State private var charisma: Int = 10
    @State private var saveProficiencies: [String: String] = [:]
    @State private var damageResponses: [String: String] = Dictionary(
        uniqueKeysWithValues: DamageType.allCases.map { ($0.rawValue, DamageResponse.regular.rawValue) }
    )
    @State private var conditionImmunities: [String] = []

    private func abilityScore(for ability: Ability) -> Int {
        switch ability {
        case .strength: return strength
        case .dexterity: return dexterity
        case .constitution: return constitution
        case .intelligence: return intelligence
        case .wisdom: return wisdom
        case .charisma: return charisma
        }
    }

    private func abilityBinding(for ability: Ability) -> Binding<Int> {
        switch ability {
        case .strength: return $strength
        case .dexterity: return $dexterity
        case .constitution: return $constitution
        case .intelligence: return $intelligence
        case .wisdom: return $wisdom
        case .charisma: return $charisma
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Add Alternate Form", systemImage: "figure.stand")
                        .font(.title2.bold())
                        .foregroundStyle(.purple)
                }
                Spacer()
                Button {
                    showJSONImport = true
                } label: {
                    Label("Import JSON", systemImage: "arrow.down.doc.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button("Add Form") {
                    var forms = pc.altForms
                    forms.append(AltForm(
                        name: name.isEmpty ? "Alternate Form" : name,
                        maxHP: max(1, maxHP),
                        armorClass: max(1, armorClass),
                        initiative: initiative,
                        speed: max(0, speed),
                        flySpeed: max(0, flySpeed),
                        swimSpeed: max(0, swimSpeed),
                        climbSpeed: max(0, climbSpeed),
                        burrowSpeed: max(0, burrowSpeed),
                        canHover: canHover,
                        strength: strength,
                        dexterity: dexterity,
                        constitution: constitution,
                        intelligence: intelligence,
                        wisdom: wisdom,
                        charisma: charisma,
                        saveProficiencies: saveProficiencies,
                        damageResponses: damageResponses,
                        conditionImmunities: conditionImmunities
                    ))
                    pc.altForms = forms
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    GroupBox {
                        Form {
                            TextField("Form Name", text: $name, prompt: Text("e.g. Wolf Form"))
                            TextField("Max HP", value: $maxHP, format: .number, prompt: Text("30"))
                            TextField("Armor Class", value: $armorClass, format: .number, prompt: Text("10"))
                            TextField("Initiative Bonus", value: $initiative, format: .number, prompt: Text("0"))
                            TextField("Walk Speed (ft)", value: $speed, format: .number, prompt: Text("30"))
                            TextField("Fly Speed (ft, 0 = none)", value: $flySpeed, format: .number, prompt: Text("0"))
                            TextField("Swim Speed (ft, 0 = none)", value: $swimSpeed, format: .number, prompt: Text("0"))
                            TextField("Climb Speed (ft, 0 = none)", value: $climbSpeed, format: .number, prompt: Text("0"))
                            TextField("Burrow Speed (ft, 0 = none)", value: $burrowSpeed, format: .number, prompt: Text("0"))
                            Toggle("Hovering", isOn: $canHover)
                        }
                        .formStyle(.grouped)
                    } label: {
                        Label("Basic Info & Movement", systemImage: "figure.stand")
                            .font(.headline)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 0) {
                                ForEach(Ability.allCases) { ability in
                                    VStack(spacing: 6) {
                                        Text(ability.rawValue)
                                            .font(.caption.bold())
                                            .foregroundStyle(.secondary)
                                        TextField("", value: abilityBinding(for: ability), format: .number)
                                            .multilineTextAlignment(.center)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 52)
                                        Text(Combatant.formattedModifier(abilityScore(for: ability)))
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
                                    let profBinding = Binding<SaveProficiency>(
                                        get: { SaveProficiency(rawValue: saveProficiencies[ability.rawValue] ?? "") ?? .none },
                                        set: { saveProficiencies[ability.rawValue] = $0.rawValue }
                                    )
                                    let baseMod = Combatant.abilityModifier(abilityScore(for: ability))
                                    let prof = SaveProficiency(rawValue: saveProficiencies[ability.rawValue] ?? "") ?? .none
                                    let saveTotal = baseMod + 2 * prof.multiplier

                                    HStack(spacing: 8) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(ability.rawValue).font(.caption.bold())
                                            Text(saveTotal >= 0 ? "+\(saveTotal)" : "\(saveTotal)")
                                                .font(.caption2).foregroundStyle(.secondary)
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
                        DamageResponseGrid(responses: $damageResponses)
                    } label: {
                        Label("Damage Responses", systemImage: "shield.lefthalf.filled")
                            .font(.headline)
                    }

                    GroupBox {
                        ConditionImmunityGrid(immunities: $conditionImmunities)
                    } label: {
                        HStack(spacing: 8) {
                            Label("Condition Immunities", systemImage: "xmark.shield.fill")
                                .font(.headline)
                            if !conditionImmunities.isEmpty {
                                Text("\(conditionImmunities.count)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(Color.red.opacity(0.18))
                                    .foregroundStyle(.red)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 600, height: 720)
        .sheet(isPresented: $showJSONImport) {
            AltFormJSONImportSheet { imported in
                name = imported.name
                maxHP = imported.maxHP
                armorClass = imported.armorClass
                initiative = imported.initiative
                speed = imported.speed
                flySpeed = imported.flySpeed
                swimSpeed = imported.swimSpeed
                climbSpeed = imported.climbSpeed
                burrowSpeed = imported.burrowSpeed
                canHover = imported.canHover
                strength = imported.strength
                dexterity = imported.dexterity
                constitution = imported.constitution
                intelligence = imported.intelligence
                wisdom = imported.wisdom
                charisma = imported.charisma
                if !imported.saveProficiencies.isEmpty { saveProficiencies = imported.saveProficiencies }
                if !imported.damageResponses.isEmpty { damageResponses = imported.damageResponses }
                if !imported.conditionImmunities.isEmpty { conditionImmunities = imported.conditionImmunities }
            }
        }
    }
}

struct InventorySection: View {
    @Bindable var pc: PlayerCharacter
    @Binding var showAddItem: Bool

    var carryColor: Color {
        let pct = pc.maxCarryWeight > 0 ? pc.currentCarryWeight / pc.maxCarryWeight : 0
        if pc.currentCarryWeight > Double(pc.strength) * pc.size.heavyEncumbranceMultiplier { return .red }
        if pct > 1 { return .orange }
        if pct > 0.75 { return .yellow }
        return .green
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(String(format: "%.1f", pc.currentCarryWeight))
                            .font(.title3.bold())
                            .foregroundStyle(carryColor)
                        Text("/ \(String(format: "%.0f", pc.maxCarryWeight)) lbs")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.18)).frame(height: 6)
                            Capsule()
                                .fill(carryColor)
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(pc.currentCarryWeight / max(1, pc.maxCarryWeight)))), height: 6)
                        }
                    }
                    .frame(height: 6)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk").font(.caption)
                        Text("Speed: \(pc.effectiveSpeed) ft")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(pc.effectiveSpeed == 0 ? .red : pc.effectiveSpeed <= 5 ? .orange : .secondary)
                    Text("STR \(pc.strength) · Max \(String(format: "%.0f", pc.maxCarryWeight)) lbs")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            Divider()

            if pc.inventory.isEmpty {
                Text("No items in inventory.")
                    .font(.subheadline).foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(pc.inventory) { item in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(.subheadline.bold())
                            Text("×\(item.quantity) · \(String(format: "%.1f", item.weightPerUnit)) lbs each")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(String(format: "%.1f lbs", item.totalWeight))
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(.secondary)
                        Button {
                            var items = pc.inventory
                            items.removeAll { $0.id == item.id }
                            pc.inventory = items
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    Divider()
                }
            }

            Button { showAddItem = true } label: {
                Label("Add Item", systemImage: "plus.circle")
            }
            .padding(10)
        }
    }
}

struct AddItemSheet: View {
    @Bindable var pc: PlayerCharacter
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var quantityText: String = "1"
    @State private var weightText: String = "1"
    @State private var showEncumberedAlert: Bool = false
    @State private var showHeavilyEncumberedAlert: Bool = false

    var parsedQuantity: Int? { Int(quantityText).flatMap { $0 > 0 ? $0 : nil } }
    var parsedWeight: Double? { Double(weightText) }
    var previewTotal: Double { Double(parsedQuantity ?? 0) * (parsedWeight ?? 0) }
    var newCarry: Double { pc.currentCarryWeight + previewTotal }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Image(systemName: "backpack.fill")
                    .font(.system(size: 32)).foregroundStyle(.brown)
                Text("Add Item").font(.title2.bold())
            }
            .padding(.top, 24).padding(.bottom, 16)
            Divider()

            VStack(spacing: 16) {
                SheetFormRow(label: "Item Name") {
                    TextField("e.g. Longsword", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                SheetFormRow(label: "Quantity") {
                    TextField("1", text: $quantityText)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                }
                SheetFormRow(label: "Weight (lbs ea)") {
                    TextField("1", text: $weightText)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                }

                if let w = parsedWeight, w > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "scalemass.fill")
                            .foregroundStyle(.secondary).font(.caption)
                        Text("Adds \(String(format: "%.1f", previewTotal)) lbs")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("→")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(String(format: "%.1f / %.0f lbs", newCarry, pc.maxCarryWeight))
                            .font(.caption.bold())
                            .foregroundStyle(newCarry > pc.maxCarryWeight ? .red : .secondary)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)

            Spacer(minLength: 16)
            Divider()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button("Add") { addItem() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || parsedQuantity == nil || parsedWeight == nil || (parsedWeight ?? 0) <= 0)
            }
            .padding(20)
        }
        .frame(width: 420, height: 330)
        .alert("Encumbered!", isPresented: $showEncumberedAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("\(pc.name) is now carrying \(String(format: "%.1f", pc.currentCarryWeight)) lbs — over the \(String(format: "%.0f", pc.maxCarryWeight)) lbs maximum.\nMovement speed reduced to 5 ft.")
        }
        .alert("Severely Encumbered!", isPresented: $showHeavilyEncumberedAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("\(pc.name) is carrying \(String(format: "%.1f", pc.currentCarryWeight)) lbs — over \(String(format: "%.0f", Double(pc.strength) * pc.size.heavyEncumbranceMultiplier)) lbs.\nMovement speed reduced to 0 ft — cannot move!")
        }
    }

    private func addItem() {
        guard let qty = parsedQuantity, let weight = parsedWeight, weight > 0 else { return }
        let prevWeight = pc.currentCarryWeight
        let heavyMax = Double(pc.strength) * pc.size.heavyEncumbranceMultiplier
        var items = pc.inventory
        items.append(InventoryItem(name: name.isEmpty ? "Item" : name, quantity: qty, weightPerUnit: weight))
        pc.inventory = items

        let newWeight = pc.currentCarryWeight
        if newWeight > heavyMax && prevWeight <= heavyMax {
            showHeavilyEncumberedAlert = true
        } else if newWeight > pc.maxCarryWeight && prevWeight <= pc.maxCarryWeight {
            showEncumberedAlert = true
        } else {
            dismiss()
        }
    }
}

struct SheetFormRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 16) {
            Text(label)
                .font(.callout.bold())
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .trailing)
            content()
            Spacer()
        }
    }
}

struct AltFormImportResult {
    var name: String
    var maxHP: Int
    var armorClass: Int
    var initiative: Int
    var speed: Int
    var flySpeed: Int
    var swimSpeed: Int
    var climbSpeed: Int
    var burrowSpeed: Int
    var canHover: Bool
    var strength: Int
    var dexterity: Int
    var constitution: Int
    var intelligence: Int
    var wisdom: Int
    var charisma: Int
    var saveProficiencies: [String: String]
    var damageResponses: [String: String]
    var conditionImmunities: [String]
}

private struct AltFormSpeedData: Decodable {
    var walk: Int?
    var fly: Int?
    var swim: Int?
    var climb: Int?
    var burrow: Int?
    var hover: Bool?
}

private struct AltFormImportData: Decodable {
    var name: String
    var max_hp: String
    var initiative_bonus: Int?
    var armor_class: Int
    var speed: AltFormSpeedData?
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

struct AltFormJSONImportSheet: View {
    let onImport: (AltFormImportResult) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var jsonText: String = ""
    @State private var errorMessage: String? = nil
    @State private var showFilePicker: Bool = false
    @State private var loadedFileName: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Import Form from JSON", systemImage: "arrow.down.doc.fill")
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
                    Image(systemName: "doc.fill").foregroundStyle(.purple)
                    Text(fileName).font(.caption.bold()).foregroundStyle(.purple)
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
                .tint(.purple)
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
            let parsed = try JSONDecoder().decode(AltFormImportData.self, from: data)

            var saveProfMap: [String: String] = [:]
            if let profs = parsed.saving_throw_proficiencies {
                for (key, isProficient) in profs {
                    saveProfMap[key.uppercased()] = isProficient
                        ? SaveProficiency.proficient.rawValue
                        : SaveProficiency.none.rawValue
                }
            }

            var responseMap: [String: String] = Dictionary(
                uniqueKeysWithValues: DamageType.allCases.map { ($0.rawValue, DamageResponse.regular.rawValue) }
            )
            if let dmgResponses = parsed.damage_responses {
                for (key, value) in dmgResponses {
                    let capitalizedKey = key.prefix(1).uppercased() + key.dropFirst()
                    if DamageType(rawValue: capitalizedKey) != nil {
                        responseMap[capitalizedKey] = (DamageResponse(rawValue: value) ?? .regular).rawValue
                    }
                }
            }

            let immunities: [String] = (parsed.condition_immunities ?? []).compactMap { raw in
                let capitalized = raw.prefix(1).uppercased() + raw.dropFirst()
                return ConditionType(rawValue: capitalized) != nil ? capitalized : nil
            }

            let result = AltFormImportResult(
                name: parsed.name.isEmpty ? "Imported Form" : parsed.name,
                maxHP: max(1, hpAverageFromFormula(parsed.max_hp)),
                armorClass: parsed.armor_class,
                initiative: parsed.initiative_bonus ?? 0,
                speed: parsed.speed?.walk ?? 30,
                flySpeed: parsed.speed?.fly ?? 0,
                swimSpeed: parsed.speed?.swim ?? 0,
                climbSpeed: parsed.speed?.climb ?? 0,
                burrowSpeed: parsed.speed?.burrow ?? 0,
                canHover: parsed.speed?.hover ?? false,
                strength: parsed.str ?? 10,
                dexterity: parsed.dex ?? 10,
                constitution: parsed.con ?? 10,
                intelligence: parsed.intelligence ?? 10,
                wisdom: parsed.wis ?? 10,
                charisma: parsed.cha ?? 10,
                saveProficiencies: saveProfMap,
                damageResponses: responseMap,
                conditionImmunities: immunities
            )
            onImport(result)
            dismiss()
        } catch {
            errorMessage = "Parse error: \(error.localizedDescription)"
        }
    }
}
