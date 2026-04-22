import SwiftUI
import SwiftData

struct ActiveCombatView: View {
    let campaign: Campaign
    @Bindable var combatEngine: CombatEngine
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlayerCharacter.name) private var allPCs: [PlayerCharacter]
    @State private var showEndCombatSummary: Bool = false
    @State private var pendingSummary: PostCombatSummary? = nil
    @State private var showMidCombatAdd: Bool = false
    @State private var showCancelConfirm: Bool = false
    @State private var scrollToCombatantID: UUID? = nil
    @State private var currentPendingSave: PendingSave? = nil

    var body: some View {
        Group {
            if combatEngine.isCombatActive {
                VStack(spacing: 0) {
                    CombatHeaderBar(
                        combatEngine: combatEngine,
                        onEndCombat: handleEndCombat,
                        onCancelCombat: { showCancelConfirm = true },
                        onAddCombatant: { showMidCombatAdd = true }
                    )
                    Divider()
                    AOEPanel(combatEngine: combatEngine)
                    Divider()
                    HStack(spacing: 0) {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(combatEngine.combatants) { combatant in
                                        CombatantRowView(combatant: combatant)
                                            .id(combatant.id)
                                        Divider()
                                            .padding(.leading, 52)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .onChange(of: scrollToCombatantID) { _, id in
                                guard let id else { return }
                                withAnimation { proxy.scrollTo(id, anchor: .top) }
                                scrollToCombatantID = nil
                            }
                        }
                        Divider()
                        CombatRightPanel(combatEngine: combatEngine) { id in
                            scrollToCombatantID = id
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Active Combat",
                    systemImage: "bolt.circle",
                    description: Text("Build an encounter in the Encounter Builder and click Start Combat.")
                )
            }
        }
        .navigationTitle(combatEngine.isCombatActive ? "Active Combat — Round \(combatEngine.currentRound)" : "Active Combat")
        .sheet(isPresented: $showEndCombatSummary, onDismiss: {
            pendingSummary = nil
            markActiveEncounterCompleted()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                combatEngine.endCombat()
            }
        }) {
            if let summary = pendingSummary {
                PostCombatSummarySheet(summary: summary) {
                    showEndCombatSummary = false
                }
            }
        }
        .sheet(isPresented: $showMidCombatAdd) {
            MidCombatAddSheet(campaign: campaign, combatEngine: combatEngine)
        }
        .alert("Cancel Combat?", isPresented: $showCancelConfirm) {
            Button("Cancel Combat", role: .destructive) {
                combatEngine.endCombat()
            }
            Button("Continue", role: .cancel) {}
        } message: {
            Text("HP changes and XP will not be saved.")
        }
        .alert(
            currentPendingSave.map { "Saving Throw — \($0.conditionName)" } ?? "",
            isPresented: Binding(
                get: { currentPendingSave != nil },
                set: { if !$0 { currentPendingSave = nil } }
            )
        ) {
            Button("Pass — Remove Condition") {
                if let save = currentPendingSave {
                    combatEngine.combatants.first { $0.id == save.combatantID }?.removeCondition(id: save.conditionID)
                }
                advancePendingSave()
            }
            Button("Fail", role: .cancel) {
                advancePendingSave()
            }
        } message: {
            if let save = currentPendingSave {
                Text("\(save.combatantName) must make a saving throw against \(save.conditionName).")
            }
        }
        .onChange(of: combatEngine.pendingSaves) { _, saves in
            if currentPendingSave == nil, let first = saves.first {
                currentPendingSave = first
            }
        }
    }

    private func advancePendingSave() {
        guard let save = currentPendingSave else { return }
        combatEngine.pendingSaves.removeAll { $0.id == save.id }
        currentPendingSave = combatEngine.pendingSaves.first
    }

    private func markActiveEncounterCompleted() {
        guard let encID = combatEngine.activeEncounterID else { return }
        let cid = campaign.id
        let descriptor = FetchDescriptor<Story>(predicate: #Predicate<Story> { $0.campaignID == cid })
        let stories = (try? modelContext.fetch(descriptor)) ?? []
        for story in stories {
            var entries = story.linkedEncounters
            var changed = false
            for i in entries.indices where entries[i].encounterID == encID && !entries[i].isCompleted {
                entries[i].isCompleted = true
                changed = true
            }
            if changed { story.linkedEncounters = entries }
        }
    }

    private func handleEndCombat() {
        let summary = combatEngine.buildPostCombatSummary(allPCs: allPCs, trackXP: campaign.trackXP)
        for result in summary.pcResults {
            guard let pc = allPCs.first(where: { $0.id == result.id }),
                  let combatant = combatEngine.combatants.first(where: { $0.pcID == result.id })
            else { continue }
            pc.currentHP = combatant.currentHP
            pc.tempHP = combatant.tempHP
            pc.resources = combatant.resources
            if campaign.trackXP {
                pc.currentXP = result.newXP
                pc.level = result.newLevel
            }
        }
        pendingSummary = summary
        showEndCombatSummary = true
    }
}

struct PostCombatSummarySheet: View {
    let summary: PostCombatSummary
    var onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Image(systemName: summary.anyLevelUp ? "star.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(summary.anyLevelUp ? .yellow : .green)

                Text("Combat Ended")
                    .font(.title.bold())

                if summary.trackXP {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles").foregroundStyle(.orange)
                        Text("\(summary.totalEnemyXP) XP Earned")
                            .font(.title3.bold())
                            .foregroundStyle(.orange)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 18)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
                } else {
                    Text("XP tracking is disabled for this campaign.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            if summary.pcResults.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.slash").font(.title2).foregroundStyle(.secondary)
                    Text("No player characters were tracked in this encounter.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 12)
            } else if summary.trackXP {
                VStack(spacing: 10) {
                    ForEach(summary.pcResults) { result in
                        PCXPResultRow(result: result)
                    }
                }
            }

            if summary.anyLevelUp {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.circle.fill").foregroundStyle(.yellow).font(.title3)
                    Text("Level Up! Update character sheets for highlighted characters.")
                        .font(.subheadline.bold()).foregroundStyle(.yellow)
                }
                .padding(14)
                .background(Color.yellow.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button {
                onConfirm()
            } label: {
                Label("End Combat", systemImage: "xmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        }
        .padding(28)
        .frame(width: 500)
    }
}

struct PCXPResultRow: View {
    let result: PCXPResult

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(result.didLevelUp ? Color.yellow.opacity(0.2) : Color.blue.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: result.didLevelUp ? "arrow.up.circle.fill" : "person.fill")
                    .foregroundStyle(result.didLevelUp ? .yellow : .blue)
                    .font(.callout)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(result.name)
                        .font(.headline)
                    if result.didLevelUp {
                        Text("LEVEL UP!")
                            .font(.caption2.bold())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.25))
                            .foregroundStyle(.yellow)
                            .clipShape(Capsule())
                    }
                }
                Text("\(result.oldXP) → \(result.newXP) XP (+\(result.xpGained))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            if result.didLevelUp {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Level \(result.oldLevel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .strikethrough()
                    Text("Level \(result.newLevel)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                }
            } else {
                Text("Level \(result.newLevel)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.blue)
            }
        }
        .padding(12)
        .background(result.didLevelUp ? Color.yellow.opacity(0.07) : Color.blue.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct CombatHeaderBar: View {
    var combatEngine: CombatEngine
    var onEndCombat: () -> Void
    var onCancelCombat: () -> Void
    var onAddCombatant: () -> Void

    var body: some View {
        ZStack(alignment: .center) {
            if let active = combatEngine.activeCombatant {
                VStack(spacing: 3) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.yellow)
                            .font(.title3)
                        if active.nickname.isEmpty {
                            Text(active.name)
                                .font(.title2.bold())
                                .foregroundStyle(active.isPC ? .blue : .red)
                        } else {
                            ChessPieceLabel(piece: active.nickname, fontSize: .title2)
                            Text("(\(active.name))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !active.playerName.isEmpty {
                        Text(active.playerName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Round \(combatEngine.currentRound)")
                            .font(.title2.bold())
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(combatEngine.roundTimeDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    let xpTotal = combatEngine.totalEnemyXP
                    if xpTotal > 0 {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("\(xpTotal) XP")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                    }

                    Button {
                        onAddCombatant()
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)
                    .help("Add combatant mid-combat")

                    Button {
                        combatEngine.prevTurn()
                    } label: {
                        Image(systemName: "arrow.left.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)
                    .help("Previous Turn")

                    Button {
                        combatEngine.nextTurn()
                    } label: {
                        Label("Next Turn", systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [.command])

                    Button {
                        onCancelCombat()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .help("Cancel combat without saving HP or awarding XP")

                    Button {
                        onEndCombat()
                    } label: {
                        Label("End Combat", systemImage: "flag.checkered")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }
}

struct AOEPanel: View {
    @Bindable var combatEngine: CombatEngine

    var body: some View {
        HStack(spacing: 14) {
            Label("Mass Modify:", systemImage: "person.3.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Amount", text: $combatEngine.aoeAmountText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 84)

            Button {
                combatEngine.applyAOE(isSubtract: false)
            } label: {
                Label("Add HP", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .tint(.green)
            .disabled(combatEngine.selectedCombatants.isEmpty || combatEngine.aoeAmountText.isEmpty)

            Button {
                combatEngine.applyAOE(isSubtract: true)
            } label: {
                Label("Sub HP", systemImage: "minus")
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(combatEngine.selectedCombatants.isEmpty || combatEngine.aoeAmountText.isEmpty)

            if !combatEngine.selectedCombatants.isEmpty {
                Text("\(combatEngine.selectedCombatants.count) selected")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            Spacer()

            Button { for c in combatEngine.combatants { c.isSelected = false } } label: {
                Text("Clear Selection")
            }
            .buttonStyle(.borderless)
            .disabled(combatEngine.selectedCombatants.isEmpty)

            Button { for c in combatEngine.combatants { c.isSelected = true } } label: {
                Text("Select All")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }
}

struct CombatantRowView: View {
    @Bindable var combatant: Combatant
    @State private var showConditionSheet: Bool = false
    @State private var isExpanded: Bool = true
    @State private var showDamageResponses: Bool = false
    @State private var showStatBlock: Bool = false
    @State private var showDeathSaveSheet: Bool = false
    @State private var showConcentrationCheckAlert: Bool = false

    var accentColor: Color { combatant.isPC ? .blue : combatant.isNPC ? .green : .red }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainRow
            if isExpanded && combatant.hasEnteredCombat {
                VStack(alignment: .leading, spacing: 0) {
                    secondaryRow
                        .padding(.leading, 56)
                        .padding(.trailing, 16)
                        .padding(.bottom, 12)
                        .padding(.top, 8)

                    if !combatant.isPC && !combatant.isNPC {
                        CollapsibleSection(
                            title: "Statblock & Saving Throws",
                            icon: "person.text.rectangle",
                            isExpanded: $showStatBlock
                        ) {
                            StatBlockView(combatant: combatant)
                                .padding(.horizontal, 56)
                                .padding(.bottom, 14)
                        }
                    }

                    CollapsibleSection(
                        title: "Damage Responses (Combat Only)",
                        icon: "shield.lefthalf.filled",
                        isExpanded: $showDamageResponses
                    ) {
                        DamageResponseGrid(responses: $combatant.damageResponsesDict)
                            .padding(.horizontal, 44)
                            .padding(.bottom, 12)
                    }
                }
            }
        }
        .background(combatant.isCurrentTurn
            ? Color(red: 0.85, green: 0.68, blue: 0.1).opacity(0.22)
            : combatant.hasEnteredCombat ? Color.clear : Color.orange.opacity(0.05))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(combatant.isCurrentTurn
                    ? Color(red: 0.95, green: 0.78, blue: 0.1)
                    : combatant.hasEnteredCombat ? Color.secondary.opacity(0.12) : Color.orange.opacity(0.4))
                .frame(width: 4)
        }
        .opacity(combatant.hasEnteredCombat ? 1.0 : 0.65)
        .contentShape(Rectangle())
        .sheet(isPresented: $showConditionSheet) {
            AddConditionView(combatant: combatant)
        }
        .sheet(isPresented: $showDeathSaveSheet) {
            DeathSaveSheet(combatant: combatant)
        }
        .alert("Concentration Check", isPresented: $showConcentrationCheckAlert) {
            Button("Still Concentrating") {
                combatant.needsConcentrationCheck = false
            }
            Button("Lost Concentration", role: .destructive) {
                combatant.isConcentrating = false
                combatant.concentrationSpellName = ""
                combatant.needsConcentrationCheck = false
            }
        } message: {
            Text("\(combatant.name) took damage. Is \(combatant.concentrationSpellName.isEmpty ? "the spell" : combatant.concentrationSpellName) still active?")
        }
        .onChange(of: combatant.isCurrentTurn) { _, isNow in
            if isNow && combatant.isPC && combatant.isDead && !combatant.isStabilized && combatant.deathSaveFailures < 3 {
                showDeathSaveSheet = true
            }
        }
        .onChange(of: combatant.needsConcentrationCheck) { _, needsCheck in
            if needsCheck { showConcentrationCheckAlert = true }
        }
    }

    var mainRow: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $combatant.isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .frame(width: 20)
                .disabled(!combatant.hasEnteredCombat)

            ZStack {
                Circle()
                    .fill(combatant.isCurrentTurn
                        ? Color.yellow.opacity(0.35)
                        : combatant.hasEnteredCombat ? accentColor.opacity(0.18) : Color.orange.opacity(0.18))
                    .frame(width: 32, height: 32)
                Group {
                    if combatant.isCurrentTurn {
                        Image(systemName: "bolt.fill").foregroundStyle(.yellow)
                    } else if !combatant.hasEnteredCombat {
                        Image(systemName: "clock.fill").foregroundStyle(.orange)
                    } else {
                        Image(systemName: combatant.isPC ? "person.fill" : combatant.isNPC ? "person.2.circle.fill" : "flame.fill")
                            .foregroundStyle(accentColor)
                    }
                }
                .font(.subheadline.bold())
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    if combatant.nickname.isEmpty {
                        Text(combatant.name)
                            .font(.title3.bold())
                            .strikethrough(combatant.isDead)
                            .foregroundStyle(combatant.isDead ? .secondary : .primary)
                    } else {
                        ChessPieceLabel(piece: combatant.nickname, fontSize: .title3)
                            .opacity(combatant.isDead ? 0.4 : 1.0)
                        Text("(\(combatant.name))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .strikethrough(combatant.isDead)
                    }

                    Text(combatant.isPC ? "PC" : combatant.isNPC ? "NPC" : "CR \(combatant.challengeRating.rawValue)")
                        .font(.caption.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(accentColor.opacity(0.18))
                        .foregroundStyle(accentColor)
                        .clipShape(Capsule())

                    if !combatant.hasEnteredCombat {
                        Text("WAITING")
                            .font(.caption.bold())
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }

                    if combatant.altFormActive {
                        Text("TRANSFORMED")
                            .font(.caption.bold())
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.purple.opacity(0.25))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }

                    if combatant.isDead {
                        Text("DOWN")
                            .font(.caption.bold())
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.gray.opacity(0.2))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.18)).frame(height: 8)
                            Capsule()
                                .fill(combatant.hpBarColor)
                                .frame(width: max(0, geo.size.width * combatant.hpPercentage), height: 8)
                        }
                    }
                    .frame(height: 8)

                    Text("\(combatant.currentHP) / \(combatant.maxHP)")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(combatant.hpBarColor)
                        .fixedSize()
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 16) {
                VStack(spacing: 3) {
                    Text("AC").font(.caption.bold()).foregroundStyle(.secondary)
                    Text("\(combatant.effectiveAC)")
                        .font(.headline.bold())
                        .foregroundStyle(combatant.acBonus > 0 ? .green : combatant.acBonus < 0 ? .red : .primary)
                    if combatant.acBonus != 0 {
                        Text(combatant.acBonus > 0 ? "+\(combatant.acBonus)" : "\(combatant.acBonus)")
                            .font(.caption2.bold())
                            .foregroundStyle(combatant.acBonus > 0 ? .green : .red)
                    }
                }
                VStack(spacing: 3) {
                    Text("Init").font(.caption.bold()).foregroundStyle(.secondary)
                    Text(combatant.initiative >= 0 ? "+\(combatant.initiative)" : "\(combatant.initiative)")
                        .font(.headline.bold())
                }
                VStack(spacing: 3) {
                    Text("Spd").font(.caption.bold()).foregroundStyle(.secondary)
                    HStack(spacing: 2) {
                        Text("\(combatant.speed)").font(.headline.bold())
                            .foregroundStyle(combatant.speed == 0 ? .red : combatant.speed <= 5 ? .orange : .primary)
                        Text("ft").font(.caption2).foregroundStyle(.secondary)
                    }
                    if combatant.flySpeed > 0 {
                        Text("Fly \(combatant.flySpeed)").font(.caption2).foregroundStyle(.blue)
                    }
                    if combatant.swimSpeed > 0 {
                        Text("Swim \(combatant.swimSpeed)").font(.caption2).foregroundStyle(.cyan)
                    }
                    if combatant.climbSpeed > 0 {
                        Text("Climb \(combatant.climbSpeed)").font(.caption2).foregroundStyle(.brown)
                    }
                    if combatant.burrowSpeed > 0 {
                        Text("Burrow \(combatant.burrowSpeed)").font(.caption2).foregroundStyle(.orange)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if combatant.tempHP > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.subheadline)
                        .foregroundStyle(.cyan)
                    Text("+\(combatant.tempHP)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.cyan)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.cyan.opacity(0.15))
                .clipShape(Capsule())
            }

            if combatant.hasEnteredCombat {
                HPDeltaField(combatant: combatant)

                Button { combatant.resetHP() } label: {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .help("Reset HP to maximum")
            } else {
                Button("Enter Combat") {
                    combatant.hasEnteredCombat = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.callout.bold())
            .foregroundStyle(.secondary)
            .frame(width: 80, alignment: .trailing)
    }

    var secondaryRow: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 32) {
                HStack(spacing: 12) {
                    sectionLabel("Damage:")
                    DamageInputView(combatant: combatant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    sectionLabel("Temp HP:")
                    TempHPSetField(combatant: combatant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if combatant.isPC && !combatant.resources.isEmpty {
                HStack(alignment: .center, spacing: 12) {
                    sectionLabel("Resources:")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(combatant.resources) { resource in
                                CombatResourceChip(combatant: combatant, resource: resource)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            HStack(alignment: .center, spacing: 32) {
                HStack(alignment: .center, spacing: 12) {
                    sectionLabel("Conditions:")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if combatant.conditions.isEmpty {
                                Text("None").font(.subheadline).foregroundStyle(.tertiary)
                            } else {
                                ForEach(combatant.conditions) { condition in
                                    ConditionBadge(condition: condition, combatant: combatant)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    Button {
                        showConditionSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help("Add condition")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !combatant.conditionImmunities.isEmpty {
                    HStack(alignment: .top, spacing: 12) {
                        sectionLabel("Immune:")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(combatant.conditionImmunities, id: \.self) { rawValue in
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.shield.fill").font(.caption2)
                                        Text(rawValue).font(.caption.bold())
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.12))
                                    .foregroundStyle(.red)
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer().frame(maxWidth: .infinity)
                }
            }

            HStack(alignment: .center, spacing: 32) {
                HStack(alignment: .center, spacing: 12) {
                    sectionLabel("AC Boost:")
                    ACBoostControl(combatant: combatant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if combatant.isPC {
                    HStack(alignment: .center, spacing: 12) {
                        sectionLabel("Focus:")
                        ConcentrationControl(combatant: combatant)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer().frame(maxWidth: .infinity)
                }
            }

            if combatant.isPC && combatant.isDead && !combatant.isStabilized {
                HStack(alignment: .center, spacing: 12) {
                    sectionLabel("Death:")
                    DeathSaveDisplay(combatant: combatant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if combatant.isPC && combatant.isDead && combatant.isStabilized {
                HStack(spacing: 8) {
                    Spacer().frame(width: 80 + 12)
                    Image(systemName: "heart.fill").foregroundStyle(.green).font(.caption)
                    Text("Stabilized").font(.caption.bold()).foregroundStyle(.green)
                    Spacer()
                }
            }

            if combatant.isPC && (!combatant.altForms.isEmpty || combatant.altFormActive) {
                HStack(alignment: .top, spacing: 12) {
                    Text(combatant.altFormActive ? "Form:" : "Alt Forms:")
                        .font(.callout.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)

                    if combatant.altFormActive {
                        HStack(spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "figure.stand")
                                    .foregroundStyle(.purple)
                                    .font(.subheadline)
                                Text(combatant.altFormName)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.purple)
                                Text("(active)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.purple.opacity(0.12))
                            .clipShape(Capsule())

                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.caption2)
                                    .foregroundStyle(.purple)
                                if let dur = combatant.altFormDurationRounds {
                                    Text("\(dur)R")
                                        .font(.caption.bold().monospacedDigit())
                                        .foregroundStyle(.purple)
                                } else {
                                    Text("∞")
                                        .font(.caption.bold())
                                        .foregroundStyle(.purple.opacity(0.6))
                                }
                                Button {
                                    combatant.altFormDurationRounds = (combatant.altFormDurationRounds ?? 0) + 1
                                } label: {
                                    Image(systemName: "plus.circle.fill").font(.caption2)
                                }
                                .buttonStyle(.plain).foregroundStyle(.purple)
                                Button {
                                    if let d = combatant.altFormDurationRounds {
                                        combatant.altFormDurationRounds = d > 1 ? d - 1 : nil
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill").font(.caption2)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(combatant.altFormDurationRounds != nil ? .purple : Color.secondary)
                                .disabled(combatant.altFormDurationRounds == nil)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.purple.opacity(0.08))
                            .clipShape(Capsule())

                            Button {
                                combatant.revertAltForm()
                            } label: {
                                Label("Revert", systemImage: "arrow.uturn.backward.circle.fill")
                                    .font(.caption.bold())
                            }
                            .buttonStyle(.bordered)
                            .tint(.purple)
                            .controlSize(.small)
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(combatant.altForms) { form in
                                    Button {
                                        combatant.activateAltForm(form)
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: "figure.stand")
                                                .font(.caption2)
                                            Text(form.name)
                                                .font(.caption.bold())
                                            Text("(\(form.maxHP) HP)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.purple)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }
}

struct CollapsibleSection<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Spacer().frame(width: 56)
                    Image(systemName: icon)
                        .font(.caption.bold())
                        .foregroundStyle(.blue.opacity(0.7))
                    Text(title)
                        .font(.callout.bold())
                        .foregroundStyle(.primary.opacity(0.6))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer().frame(width: 16)
                }
                .padding(.vertical, 9)
                .background(Color.primary.opacity(0.04))
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
            }
        }
    }
}

struct SaveThrowCell: View {
    let combatant: Combatant
    let ability: Ability

    var body: some View {
        let mod = combatant.savingThrowModifier(for: ability)
        let prof = combatant.saveProficiency(for: ability)
        let modText = mod >= 0 ? "+\(mod)" : "\(mod)"
        let modColor: Color = prof == .none ? .primary : .blue
        let profLabel = prof == .expertise ? "E" : "P"
        let profBg: Color = prof == .expertise ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2)
        let profFg: Color = prof == .expertise ? .purple : .blue

        return HStack(spacing: 5) {
            Text(ability.rawValue)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
            Text(modText)
                .font(.caption.bold())
                .foregroundStyle(modColor)
            if prof != .none {
                Text(profLabel)
                    .font(.caption2.bold())
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(profBg)
                    .foregroundStyle(profFg)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

struct StatBlockView: View {
    let combatant: Combatant

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 0) {
                ForEach(Ability.allCases) { ability in
                    let score = combatant.abilityScore(for: ability)
                    VStack(spacing: 4) {
                        Text(ability.rawValue)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        Text("\(score)")
                            .font(.callout.bold())
                        Text(Combatant.formattedModifier(score))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    if ability != .charisma {
                        Spacer().frame(width: 6)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Saving Throws")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Ability.allCases) { ability in
                        SaveThrowCell(combatant: combatant, ability: ability)
                    }
                }
            }

            HStack(spacing: 16) {
                Label("CR \(combatant.challengeRating.rawValue)", systemImage: "star.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                Label("\(combatant.encounterXP) XP", systemImage: "sparkles")
                    .font(.caption.bold())
                    .foregroundStyle(.purple)
                Label("Prof +\(combatant.challengeRating.proficiencyBonus)", systemImage: "plus.circle")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct HPDeltaField: View {
    var combatant: Combatant
    @FocusState private var focused: Bool
    @State private var text: String = ""

    var body: some View {
        VStack(spacing: 3) {
            Text("± HP").font(.caption.bold()).foregroundStyle(.secondary)
            TextField("±", text: $text)
                .focused($focused)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: 68)
                .font(.callout)
                .onChange(of: focused) { _, isFocused in
                    if isFocused { text = "" } else { applyAndUpdate() }
                }
                .onSubmit { applyAndUpdate(); focused = false }
                .onAppear { text = "\(combatant.currentHP)" }
                .onChange(of: combatant.currentHP) { _, hp in if !focused { text = "\(hp)" } }
        }
    }

    private func applyAndUpdate() {
        if !text.isEmpty, let delta = Int(text) {
            combatant.currentHP = max(0, min(combatant.maxHP, combatant.currentHP + delta))
        }
        text = "\(combatant.currentHP)"
    }
}

struct TempHPSetField: View {
    var combatant: Combatant
    @State private var text: String = ""

    var body: some View {
        HStack(spacing: 10) {
            TextField("Amount", text: $text, prompt: Text("0"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 76)
                .font(.callout)
            Button("Set Temp HP") {
                if let amount = Int(text), amount >= 0 {
                    combatant.applyTempHP(amount)
                }
                text = ""
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .disabled(Int(text) == nil)
            if combatant.tempHP > 0 {
                Button {
                    combatant.tempHP = 0
                } label: {
                    Text("Clear (\(combatant.tempHP))")
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.secondary)
                .controlSize(.regular)
            }
        }
    }
}

struct DamageInputView: View {
    var combatant: Combatant
    @State private var damageText: String = ""
    @State private var selectedType: DamageType = .slashing

    var body: some View {
        HStack(spacing: 10) {
            TextField("Amount", text: $damageText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 76)
                .font(.callout)

            Picker("Type", selection: $selectedType) {
                ForEach(DamageType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .labelsHidden()
            .frame(width: 130)

            let response = combatant.response(for: selectedType)
            Text(response.abbreviation)
                .font(.callout.bold())
                .frame(width: 30)
                .foregroundStyle(damageResponseColor(response))
                .help(response.rawValue)

            Button("Apply") {
                guard let amount = Int(damageText), amount > 0 else { return }
                combatant.applyDamage(amount, type: selectedType)
                damageText = ""
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.regular)
            .disabled(Int(damageText) == nil || (Int(damageText) ?? 0) <= 0)
        }
    }

    func damageResponseColor(_ response: DamageResponse) -> Color {
        switch response {
        case .immune: return .blue
        case .resistant: return .green
        case .vulnerable: return .red
        case .regular: return .secondary
        }
    }
}

struct CombatResourceChip: View {
    var combatant: Combatant
    let resource: CharacterResource
    @State private var showConcentrationSheet: Bool = false
    @State private var capturedSpellName: String = ""

    var body: some View {
        HStack(spacing: 6) {
            if resource.requiresConcentration {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(.purple)
            }

            Text(resource.name)
                .font(.caption.bold())
                .lineLimit(1)

            Text("\(resource.currentValue)/\(resource.maxValue)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(resource.currentValue == 0 ? .red : .secondary)

            Button {
                capturedSpellName = combatant.concentrationSpellName
                showConcentrationSheet = true
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.caption)
                    .foregroundStyle(resource.currentValue > 0 ? Color.red : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(resource.currentValue <= 0)

            Button {
                if let idx = combatant.resources.firstIndex(where: { $0.id == resource.id }) {
                    combatant.resources[idx].currentValue = combatant.resources[idx].maxValue
                }
            } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .help("Restore to max")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(resource.requiresConcentration ? Color.purple.opacity(0.08) : Color.secondary.opacity(0.1))
        .clipShape(Capsule())
        .overlay(resource.requiresConcentration ? Capsule().stroke(Color.purple.opacity(0.25), lineWidth: 1) : nil)
        .sheet(isPresented: $showConcentrationSheet) {
            ConcentrationResourceSheet(
                resource: resource,
                combatant: combatant,
                previousSpellName: capturedSpellName
            )
        }
    }

    private func useResource() {
        if let idx = combatant.resources.firstIndex(where: { $0.id == resource.id }) {
            combatant.resources[idx].currentValue = max(0, combatant.resources[idx].currentValue - 1)
        }
    }
}

struct ConcentrationResourceSheet: View {
    let resource: CharacterResource
    var combatant: Combatant
    let previousSpellName: String
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .askIfRequires
    @State private var spellName: String = ""

    enum Step { case askIfRequires, askIfSucceeded }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundStyle(.purple)
                Text(step == .askIfRequires ? "Concentration Check" : "Cast Result")
                    .font(.title2.bold())
            }
            .padding(.top, 28)
            .padding(.bottom, 16)

            Divider()

            if step == .askIfRequires {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles").foregroundStyle(.purple).font(.caption)
                        Text("Currently concentrating on: \(previousSpellName.isEmpty ? "a spell" : previousSpellName)")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("Does \(resource.name) require concentration?")
                        .font(.headline)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)

                Divider()

                HStack(spacing: 12) {
                    Button("No — Cast Freely") {
                        useResource()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)

                    Button("Yes — Requires Concentration") {
                        combatant.isConcentrating = false
                        combatant.concentrationSpellName = ""
                        spellName = resource.name
                        step = .askIfSucceeded
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
                .padding(20)

            } else {
                VStack(alignment: .leading, spacing: 14) {
                    if !previousSpellName.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.orange).font(.caption)
                            Text("Concentration on \(previousSpellName) has ended.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Text("Did the cast succeed?")
                        .font(.headline)
                    HStack(spacing: 10) {
                        Text("Spell name:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("e.g. Hold Person", text: $spellName)
                            .textFieldStyle(.roundedBorder)
                    }
                    Text("If yes — concentrating on the spell above.\nIf no — not concentrating on anything.")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)

                Divider()

                HStack(spacing: 12) {
                    Button("No — Cast Failed") {
                        useResource()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)

                    Button("Yes — Now Concentrating") {
                        combatant.isConcentrating = true
                        combatant.concentrationSpellName = spellName
                        useResource()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(20)
            }
        }
        .frame(width: 400)
    }

    private func useResource() {
        if let idx = combatant.resources.firstIndex(where: { $0.id == resource.id }) {
            combatant.resources[idx].currentValue = max(0, combatant.resources[idx].currentValue - 1)
        }
    }
}

struct ChessPieceLabel: View {
    let piece: String
    let fontSize: Font

    var isWhite: Bool { whitePieces.contains(piece) }
    var isBlack: Bool { blackPieces.contains(piece) }
    var isChess: Bool { isWhite || isBlack }

    var bgColor: Color {
        isWhite ? Color(red: 0.90, green: 0.87, blue: 0.76) : Color(red: 0.10, green: 0.10, blue: 0.13)
    }
    var fgColor: Color {
        isWhite ? Color(red: 0.08, green: 0.06, blue: 0.04) : .white
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(piece)
                .font(fontSize)
                .foregroundStyle(isChess ? fgColor : .primary)
                .padding(.horizontal, isChess ? 6 : 0)
                .padding(.vertical, isChess ? 3 : 0)
                .background(isChess ? bgColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 5))

            if isChess {
                Text(isWhite ? "White" : "Black")
                    .font(.caption2.bold())
                    .foregroundStyle(isWhite
                        ? Color(red: 0.90, green: 0.87, blue: 0.76)
                        : Color(white: 0.55))
            }
        }
    }
}

struct ACBoostControl: View {
    var combatant: Combatant

    var body: some View {
        HStack(spacing: 10) {
            Button {
                combatant.acBonus -= 1
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(combatant.acBonus > 0 ? .red : .secondary)
            }
            .buttonStyle(.plain)

            Text(combatant.acBonus == 0 ? "0" : combatant.acBonus > 0 ? "+\(combatant.acBonus)" : "\(combatant.acBonus)")
                .font(.subheadline.bold().monospacedDigit())
                .frame(width: 32, alignment: .center)
                .foregroundStyle(combatant.acBonus > 0 ? .green : combatant.acBonus < 0 ? .red : .secondary)

            Button {
                combatant.acBonus += 1
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)

            if combatant.acBonus != 0 {
                Divider().frame(height: 20)

                Toggle("Permanent", isOn: Binding(
                    get: { combatant.acBonusDuration == nil },
                    set: { isPerm in combatant.acBonusDuration = isPerm ? nil : 1 }
                ))
                .toggleStyle(.checkbox)
                .font(.caption)

                if let dur = combatant.acBonusDuration {
                    HStack(spacing: 5) {
                        Text("Rounds:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Stepper("", value: Binding(
                            get: { dur },
                            set: { combatant.acBonusDuration = $0 }
                        ), in: 1...99)
                        .labelsHidden()
                        Text("\(dur)")
                            .font(.caption.bold().monospacedDigit())
                            .frame(width: 24)
                    }
                }

                Button {
                    combatant.acBonus = 0
                    combatant.acBonusDuration = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove AC boost")
            }
        }
    }
}

struct ConcentrationControl: View {
    var combatant: Combatant
    @State private var spellNameText: String = ""

    var body: some View {
        if combatant.isConcentrating {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                    .font(.caption)
                Text(combatant.concentrationSpellName.isEmpty ? "Concentrating" : combatant.concentrationSpellName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.purple)
                Button {
                    combatant.isConcentrating = false
                    combatant.concentrationSpellName = ""
                } label: {
                    Label("End", systemImage: "xmark.circle.fill")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.purple.opacity(0.12))
            .clipShape(Capsule())
        } else {
            HStack(spacing: 8) {
                TextField("Spell name", text: $spellNameText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                Button("Concentrate") {
                    combatant.isConcentrating = true
                    combatant.concentrationSpellName = spellNameText
                    spellNameText = ""
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .controlSize(.small)
                .disabled(spellNameText.isEmpty)
            }
        }
    }
}

struct DeathSaveDisplay: View {
    var combatant: Combatant

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i < combatant.deathSaveSuccesses ? Color.green : Color.secondary.opacity(0.3))
                        .frame(width: 14, height: 14)
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i < combatant.deathSaveFailures ? Color.red : Color.secondary.opacity(0.3))
                        .frame(width: 14, height: 14)
                }
            }
            if combatant.deathSaveFailures >= 3 {
                Text("DEAD")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }
        }
    }
}

struct DeathSaveSheet: View {
    var combatant: Combatant
    @Environment(\.dismiss) private var dismiss
    @State private var rollText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.red)
                Text("Death Saving Throw")
                    .font(.title2.bold())
                Text("\(combatant.name) is at 0 HP")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 28)
            .padding(.bottom, 16)

            HStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("Successes")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(i < combatant.deathSaveSuccesses ? Color.green : Color.secondary.opacity(0.25))
                                .frame(width: 20, height: 20)
                        }
                    }
                }
                VStack(spacing: 8) {
                    Text("Failures")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(i < combatant.deathSaveFailures ? Color.red : Color.secondary.opacity(0.25))
                                .frame(width: 20, height: 20)
                        }
                    }
                }
            }
            .padding(.vertical, 16)

            Divider()

            VStack(spacing: 12) {
                Text("Enter d20 roll:")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    TextField("1–20", text: $rollText)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .frame(width: 80)
                        .onSubmit { applyRoll() }
                    Button("Apply") { applyRoll() }
                        .buttonStyle(.borderedProminent)
                        .disabled(Int(rollText) == nil)
                }
                Text("1 = 2 failures  ·  2–10 = failure  ·  11–19 = success  ·  20 = revive 1 HP")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 16)

            Divider()

            HStack(spacing: 12) {
                Button {
                    combatant.deathSaveSuccesses = min(3, combatant.deathSaveSuccesses + 1)
                    checkOutcome()
                } label: {
                    Label("+Success", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.bordered)
                .tint(.green)
                .controlSize(.small)

                Button {
                    combatant.deathSaveFailures = min(3, combatant.deathSaveFailures + 1)
                    checkOutcome()
                } label: {
                    Label("+Failure", systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)

                Spacer()

                Button("Dismiss") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 400)
    }

    private func applyRoll() {
        guard let roll = Int(rollText) else { return }
        rollText = ""
        if roll == 1 {
            combatant.deathSaveFailures = min(3, combatant.deathSaveFailures + 2)
        } else if roll <= 10 {
            combatant.deathSaveFailures = min(3, combatant.deathSaveFailures + 1)
        } else if roll == 20 {
            combatant.currentHP = 1
            combatant.deathSaveSuccesses = 0
            combatant.deathSaveFailures = 0
            combatant.isStabilized = false
            dismiss()
            return
        } else {
            combatant.deathSaveSuccesses = min(3, combatant.deathSaveSuccesses + 1)
        }
        checkOutcome()
    }

    private func checkOutcome() {
        if combatant.deathSaveSuccesses >= 3 {
            combatant.isStabilized = true
            dismiss()
        } else if combatant.deathSaveFailures >= 3 {
            dismiss()
        }
    }
}

struct MidCombatAddSheet: View {
    let campaign: Campaign
    var combatEngine: CombatEngine
    @Environment(\.dismiss) private var dismiss

    @Query private var allPCs: [PlayerCharacter]
    @Query private var allTemplates: [MonsterTemplate]
    @Query private var allNPCs: [NPCTemplate]

    @State private var mode: AddMode = .monster
    @State private var selectedPC: PlayerCharacter? = nil
    @State private var selectedTemplate: MonsterTemplate? = nil
    @State private var selectedNPC: NPCTemplate? = nil
    @State private var initiativeText: String = ""
    @State private var hasEnteredCombat: Bool = true
    @State private var nickname: String = ""

    enum AddMode { case pc, monster, npc }

    init(campaign: Campaign, combatEngine: CombatEngine) {
        self.campaign = campaign
        self.combatEngine = combatEngine
        let cid = campaign.id
        _allPCs = Query(
            filter: #Predicate<PlayerCharacter> { $0.campaignID == cid },
            sort: [SortDescriptor(\PlayerCharacter.name)]
        )
        _allTemplates = Query(
            filter: #Predicate<MonsterTemplate> { t in t.isGlobal || t.campaignID == cid },
            sort: [SortDescriptor(\MonsterTemplate.name)]
        )
        _allNPCs = Query(
            filter: #Predicate<NPCTemplate> { $0.campaignID == cid },
            sort: [SortDescriptor(\NPCTemplate.name)]
        )
    }

    var existingPCIDs: Set<UUID> {
        Set(combatEngine.combatants.compactMap { $0.isPC ? $0.pcID : nil })
    }

    var availablePCs: [PlayerCharacter] {
        allPCs.filter { !existingPCIDs.contains($0.id) }
    }

    var initiativeBonus: Int {
        switch mode {
        case .monster: return selectedTemplate?.initiative ?? 0
        case .npc: return selectedNPC?.initiative ?? 0
        case .pc: return 0
        }
    }

    var parsedInitiative: Int? {
        guard let roll = Int(initiativeText) else { return nil }
        return roll + initiativeBonus
    }

    var canAdd: Bool {
        guard parsedInitiative != nil else { return false }
        switch mode {
        case .pc: return selectedPC != nil
        case .monster: return selectedTemplate != nil
        case .npc: return selectedNPC != nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32)).foregroundStyle(.orange)
                Text("Add Combatant").font(.title2.bold())
            }
            .padding(.top, 24).padding(.bottom, 16)

            Divider()

            VStack(spacing: 20) {
                Picker("", selection: $mode) {
                    Text("Monster").tag(AddMode.monster)
                    Text("PC").tag(AddMode.pc)
                    Text("NPC Ally").tag(AddMode.npc)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: mode) { _, _ in
                    selectedPC = nil
                    selectedTemplate = nil
                    selectedNPC = nil
                    nickname = ""
                }
                .padding(.horizontal, 28)

                if mode == .pc {
                    if availablePCs.isEmpty {
                        Text("All campaign characters are already in combat.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        SheetFormRow(label: "Character") {
                            Picker("", selection: $selectedPC) {
                                Text("Select...").tag(nil as PlayerCharacter?)
                                ForEach(availablePCs) { pc in
                                    Text(pc.displayName).tag(pc as PlayerCharacter?)
                                }
                            }
                            .frame(width: 200)
                        }
                        .padding(.horizontal, 28)
                    }
                } else if mode == .npc {
                    if allNPCs.isEmpty {
                        Text("No NPCs defined. Add them in the NPC Library first.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        SheetFormRow(label: "NPC Ally") {
                            Picker("", selection: $selectedNPC) {
                                Text("Select...").tag(nil as NPCTemplate?)
                                ForEach(allNPCs) { npc in
                                    Text(npc.name).tag(npc as NPCTemplate?)
                                }
                            }
                            .frame(width: 200)
                        }
                        .padding(.horizontal, 28)
                    }
                } else {
                    VStack(spacing: 12) {
                        SheetFormRow(label: "Monster") {
                            Picker("", selection: $selectedTemplate) {
                                Text("Select...").tag(nil as MonsterTemplate?)
                                ForEach(allTemplates) { t in
                                    Text(t.name).tag(t as MonsterTemplate?)
                                }
                            }
                            .frame(width: 200)
                        }
                        if selectedTemplate != nil {
                            SheetFormRow(label: "Nickname") {
                                TextField("Optional", text: $nickname)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 200)
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                    HStack(spacing: 12) {
                        Text("Initiative")
                            .font(.callout.bold()).foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .trailing)
                        HStack(spacing: 8) {
                            TextField("d20 roll", text: $initiativeText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            if initiativeBonus != 0 {
                                Text(initiativeBonus > 0 ? "+\(initiativeBonus)" : "\(initiativeBonus)")
                                    .font(.caption.bold())
                                    .foregroundStyle(initiativeBonus > 0 ? .green : .red)
                            }
                            if let total = parsedInitiative {
                                Text("= \(total)")
                                    .font(.subheadline.bold().monospacedDigit())
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    HStack {
                        Spacer().frame(width: 80 + 28 + 12)
                        Toggle("Enters combat immediately", isOn: $hasEnteredCombat)
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 16)

            Spacer(minLength: 0)
            Divider()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") {
                    addCombatant()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .keyboardShortcut(.defaultAction)
                .disabled(!canAdd)
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(width: 460, height: 400)
    }

    private func addCombatant() {
        guard let total = parsedInitiative else { return }
        let c: Combatant

        switch mode {
        case .pc:
            guard let pc = selectedPC else { return }
            c = Combatant.fromPC(pc, initiative: total)
        case .monster:
            guard let template = selectedTemplate else { return }
            c = Combatant.fromTemplate(template, suffix: "", initiative: total)
            c.nickname = nickname
        case .npc:
            guard let npc = selectedNPC else { return }
            c = Combatant.fromNPCTemplate(npc, initiative: total)
        }

        c.hasEnteredCombat = hasEnteredCombat
        combatEngine.combatants.append(c)
        combatEngine.combatants.sort { $0.initiative > $1.initiative }
        if let idx = combatEngine.combatants.firstIndex(where: { $0.isCurrentTurn }) {
            combatEngine.currentTurnIndex = idx
        }
    }
}

struct CombatRightPanel: View {
    var combatEngine: CombatEngine
    var onSelectCombatant: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Combatants")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(combatEngine.combatants) { combatant in
                        CombatantMiniRow(combatant: combatant) {
                            onSelectCombatant(combatant.id)
                        }
                        Divider()
                    }
                }
            }
        }
        .frame(width: 210)
    }
}

private struct CombatantMiniRow: View {
    var combatant: Combatant
    var onTap: () -> Void

    var accentColor: Color { combatant.isPC ? .blue : combatant.isNPC ? .green : .red }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(combatant.isCurrentTurn ? Color.yellow.opacity(0.35) : accentColor.opacity(0.18))
                    .frame(width: 28, height: 28)
                if combatant.nickname.isEmpty {
                    Image(systemName: combatant.isPC ? "person.fill" : combatant.isNPC ? "person.2.circle.fill" : "flame.fill")
                        .font(.caption.bold())
                        .foregroundStyle(combatant.isCurrentTurn ? .yellow : accentColor)
                } else {
                    Text(combatant.nickname)
                        .font(.caption.bold())
                        .foregroundStyle(combatant.isCurrentTurn ? .yellow : accentColor)
                        .lineLimit(1)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(combatant.name)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .strikethrough(combatant.isDead)
                    .foregroundStyle(combatant.isDead ? .secondary : .primary)
                HStack(spacing: 4) {
                    Text("\(combatant.currentHP)/\(combatant.maxHP)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(combatant.hpBarColor)
                    if combatant.tempHP > 0 {
                        Text("+\(combatant.tempHP)")
                            .font(.caption2.bold())
                            .foregroundStyle(.cyan)
                    }
                    if combatant.hasSkipCondition {
                        Image(systemName: "pause.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(combatant.isCurrentTurn ? Color.yellow.opacity(0.12) : .clear)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
