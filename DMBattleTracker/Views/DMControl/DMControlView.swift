import SwiftUI
import SwiftData

struct DMControlView: View {
    let campaign: Campaign

    @Query private var characters: [PlayerCharacter]
    @State private var showShortRest: Bool = false

    init(campaign: Campaign) {
        self.campaign = campaign
        let cid = campaign.id
        _characters = Query(
            filter: #Predicate<PlayerCharacter> { $0.campaignID == cid },
            sort: [SortDescriptor(\PlayerCharacter.name)]
        )
    }

    var body: some View {
        Group {
            if characters.isEmpty {
                ContentUnavailableView(
                    "No Characters",
                    systemImage: "person.2",
                    description: Text("Add player characters in the PC Library first.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        restBar
                        Divider()
                        ForEach(characters) { pc in
                            DMControlRow(pc: pc)
                            Divider()
                        }
                    }
                }
            }
        }
        .navigationTitle("DM Control")
        .sheet(isPresented: $showShortRest) {
            DMShortRestSheet(characters: characters)
        }
    }

    var restBar: some View {
        HStack(spacing: 12) {
            Label("Party Status", systemImage: "person.3.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            Spacer()

            let totalHP = characters.reduce(0) { $0 + $1.currentHP }
            let totalMaxHP = characters.reduce(0) { $0 + $1.maxHP }
            HStack(spacing: 6) {
                Image(systemName: "heart.fill").foregroundStyle(.red).font(.caption)
                Text("Party HP: \(totalHP) / \(totalMaxHP)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

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
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private func applyLongRest() {
        for pc in characters {
            pc.currentHP = pc.maxHP
            pc.tempHP = 0
            var rs = pc.resources
            for i in rs.indices { rs[i].currentValue = rs[i].maxValue }
            pc.resources = rs
        }
    }
}

struct DMControlRow: View {
    @Bindable var pc: PlayerCharacter
    @State private var goldText: String = ""
    @State private var silverText: String = ""
    @State private var copperText: String = ""
    @FocusState private var goldFocused: Bool
    @FocusState private var silverFocused: Bool
    @FocusState private var copperFocused: Bool

    var hpColor: Color {
        let pct = Double(pc.currentHP) / Double(max(1, pc.maxHP))
        if pct > 0.5 { return .green }
        if pct > 0.25 { return .yellow }
        if pct > 0 { return .red }
        return .gray
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                nameColumn
                Divider().frame(height: 72)
                hpColumn
                Divider().frame(height: 72)
                statsColumn
                Divider().frame(height: 72)
                sensesColumn
                Divider().frame(height: 72)
                xpColumn
                Divider().frame(height: 72)
                goldColumn
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)

            if !pc.resources.isEmpty {
                resourcesRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
    }

    var nameColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            if pc.playerName.isEmpty {
                Text(pc.name)
                    .font(.headline)
            } else {
                Text(pc.playerName)
                    .font(.headline)
                Text("(\(pc.name))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 160, alignment: .leading)
        .padding(.horizontal, 16)
    }

    var hpColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HP")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                TextField("", value: $pc.currentHP, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .frame(width: 52)
                Text("/ \(pc.maxHP)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                if pc.tempHP > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "shield.lefthalf.filled").font(.caption2)
                        Text("+\(pc.tempHP)").font(.caption.bold())
                    }
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 5)
                    Capsule()
                        .fill(hpColor)
                        .frame(width: max(0, geo.size.width * Double(pc.currentHP) / Double(max(1, pc.maxHP))), height: 5)
                }
            }
            .frame(height: 5)
            let carry = pc.currentCarryWeight
            let maxCarry = pc.maxCarryWeight
            let carryColor: Color = carry > Double(pc.strength) * pc.size.heavyEncumbranceMultiplier ? .red : carry > maxCarry ? .orange : .secondary
            HStack(spacing: 4) {
                Image(systemName: "bag.fill").font(.caption2).foregroundStyle(carryColor)
                Text(String(format: "%.0f / %.0f lb", carry, maxCarry))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(carryColor)
            }
        }
        .frame(width: 150)
        .padding(.horizontal, 14)
    }

    var statsColumn: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                VStack(spacing: 3) {
                    Text("AC").font(.caption.bold()).foregroundStyle(.secondary)
                    Text("\(pc.armorClass)").font(.headline.bold())
                }
                VStack(spacing: 3) {
                    Text("Lv").font(.caption.bold()).foregroundStyle(.secondary)
                    Text("\(pc.level)").font(.headline.bold())
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                let spd = pc.effectiveSpeed
                HStack(spacing: 3) {
                    Image(systemName: "figure.walk").font(.caption2).foregroundStyle(.secondary)
                    Text("\(spd) ft").font(.caption2.bold().monospacedDigit())
                        .foregroundStyle(spd == 0 ? .red : spd <= 5 ? .orange : .primary)
                }
                if pc.flySpeed > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "bird").font(.caption2).foregroundStyle(.blue)
                        Text("\(pc.flySpeed) ft").font(.caption2.bold().monospacedDigit()).foregroundStyle(.blue)
                    }
                }
                if pc.swimSpeed > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "drop.fill").font(.caption2).foregroundStyle(.cyan)
                        Text("\(pc.swimSpeed) ft").font(.caption2.bold().monospacedDigit()).foregroundStyle(.cyan)
                    }
                }
                if pc.climbSpeed > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.right").font(.caption2).foregroundStyle(.brown)
                        Text("\(pc.climbSpeed) ft").font(.caption2.bold().monospacedDigit()).foregroundStyle(.brown)
                    }
                }
                if pc.burrowSpeed > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill").font(.caption2).foregroundStyle(.orange)
                        Text("\(pc.burrowSpeed) ft").font(.caption2.bold().monospacedDigit()).foregroundStyle(.orange)
                    }
                }
            }
        }
        .frame(width: 130)
        .padding(.horizontal, 14)
    }

    var xpColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("XP").font(.caption.bold()).foregroundStyle(.secondary)
            Text("\(pc.currentXP)")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(.purple)
            if let nextXP = pc.xpForNextLevel {
                let needed = nextXP - pc.currentXP
                Text("\(needed) to next")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Max Level")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
        .frame(width: 110)
        .padding(.horizontal, 14)
    }

    private var totalCP: Int { pc.gold * 100 + pc.silver * 10 + pc.copper }

    var goldColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            wealthRow(
                icon: "circle.fill", iconColor: .yellow,
                amount: totalCP / 100, unit: "gp",
                text: $goldText, focused: $goldFocused,
                apply: applyGold
            )
            wealthRow(
                icon: "circle.fill", iconColor: Color(white: 0.7),
                amount: totalCP / 10, unit: "sp",
                text: $silverText, focused: $silverFocused,
                apply: applySilver
            )
            wealthRow(
                icon: "circle.fill", iconColor: Color(red: 0.8, green: 0.5, blue: 0.2),
                amount: totalCP, unit: "cp",
                text: $copperText, focused: $copperFocused,
                apply: applyCopper
            )
        }
        .frame(width: 160)
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private func wealthRow(
        icon: String, iconColor: Color,
        amount: Int, unit: String,
        text: Binding<String>, focused: FocusState<Bool>.Binding,
        apply: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(iconColor).font(.caption2)
            Text("\(amount) \(unit)").font(.caption.bold()).frame(width: 52, alignment: .leading)
            TextField("±", text: text, prompt: Text("±"))
                .focused(focused)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .frame(width: 46)
                .font(.caption)
                .onSubmit { apply(); focused.wrappedValue = false }
                .onChange(of: focused.wrappedValue) { _, isFocused in
                    if !isFocused { apply() }
                }
        }
    }

    var resourcesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pc.resources) { resource in
                    DMResourceControl(pc: pc, resource: resource)
                }
            }
            .padding(.vertical, 2)
        }
    }

    var sensesColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            senseItem(icon: "eye.fill", label: "Perc", value: pc.passivePerception, color: .blue)
            senseItem(icon: "brain.fill", label: "Ins", value: pc.passiveInsight, color: .purple)
            senseItem(icon: "magnifyingglass", label: "Inv", value: pc.passiveInvestigation, color: .orange)
            if pc.darkvisionRange > 0 {
                senseItem(icon: "moon.stars.fill", label: "DV", value: pc.darkvisionRange, color: .indigo, unit: "ft")
            }
        }
        .frame(width: 110, alignment: .leading)
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private func senseItem(icon: String, label: String, value: Int, color: Color, unit: String = "") -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption2).foregroundStyle(color)
            Text(label).font(.caption2.bold()).foregroundStyle(.secondary)
            Text(unit.isEmpty ? "\(value)" : "\(value) \(unit)")
                .font(.caption2.bold().monospacedDigit())
                .foregroundStyle(color)
        }
    }

    private func applyGold() {
        guard !goldText.isEmpty, let delta = Int(goldText) else { return }
        let t = max(0, totalCP + delta * 100)
        pc.gold = t / 100; pc.silver = (t % 100) / 10; pc.copper = t % 10
        goldText = ""
    }

    private func applySilver() {
        guard !silverText.isEmpty, let delta = Int(silverText) else { return }
        let t = max(0, totalCP + delta * 10)
        pc.gold = t / 100; pc.silver = (t % 100) / 10; pc.copper = t % 10
        silverText = ""
    }

    private func applyCopper() {
        guard !copperText.isEmpty, let delta = Int(copperText) else { return }
        let t = max(0, totalCP + delta)
        pc.gold = t / 100; pc.silver = (t % 100) / 10; pc.copper = t % 10
        copperText = ""
    }
}

struct DMResourceControl: View {
    @Bindable var pc: PlayerCharacter
    let resource: CharacterResource

    var fillColor: Color {
        if resource.maxValue == 0 { return .secondary }
        let pct = Double(resource.currentValue) / Double(resource.maxValue)
        if pct >= 1.0 { return resource.restType == .longRest ? .indigo : .blue }
        if pct > 0 { return .orange }
        return .red
    }

    var restColor: Color { resource.restType == .longRest ? .indigo : .blue }

    var body: some View {
        HStack(spacing: 0) {
            Button { adjust(by: -1) } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(resource.currentValue > 0 ? fillColor : Color.secondary.opacity(0.35))
            }
            .buttonStyle(.plain)
            .disabled(resource.currentValue <= 0)

            VStack(spacing: 2) {
                Text(resource.name)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Text("\(resource.currentValue)")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(fillColor)
                    Text("/ \(resource.maxValue)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(resource.restType == .longRest ? "LR" : "SR")
                        .font(.caption2.bold())
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(restColor.opacity(0.15))
                        .foregroundStyle(restColor)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 8)

            Button { adjust(by: +1) } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(resource.currentValue < resource.maxValue ? fillColor : Color.secondary.opacity(0.35))
            }
            .buttonStyle(.plain)
            .disabled(resource.currentValue >= resource.maxValue)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(fillColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(fillColor.opacity(0.25), lineWidth: 1))
    }

    private func adjust(by delta: Int) {
        var rs = pc.resources
        guard let idx = rs.firstIndex(where: { $0.id == resource.id }) else { return }
        rs[idx].currentValue = min(rs[idx].maxValue, max(0, rs[idx].currentValue + delta))
        pc.resources = rs
    }
}

struct ResourceChip: View {
    let resource: CharacterResource

    var fillColor: Color {
        if resource.maxValue == 0 { return .secondary }
        let pct = Double(resource.currentValue) / Double(resource.maxValue)
        if pct >= 1.0 { return resource.restType == .longRest ? .indigo : .blue }
        if pct > 0 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(resource.name)
                .font(.caption.bold())
                .lineLimit(1)
            Text("\(resource.currentValue)/\(resource.maxValue)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(resource.currentValue == 0 ? .red : .secondary)
            Text(resource.restType == .longRest ? "LR" : "SR")
                .font(.caption2.bold())
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(resource.restType == .longRest ? Color.indigo.opacity(0.2) : Color.blue.opacity(0.2))
                .foregroundStyle(resource.restType == .longRest ? .indigo : .blue)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(fillColor.opacity(0.1))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(fillColor.opacity(0.3), lineWidth: 1))
    }
}

struct DMShortRestSheet: View {
    let characters: [PlayerCharacter]
    @Environment(\.dismiss) private var dismiss
    @State private var hpEntries: [UUID: String] = [:]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
                Text("Short Rest")
                    .font(.title2.bold())
                Text("Enter HP recovery for each character (hit dice).\nShort Rest resources will be restored automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(characters) { pc in
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 2) {
                                if pc.playerName.isEmpty {
                                    Text(pc.name).font(.headline)
                                } else {
                                    Text(pc.playerName).font(.headline)
                                    Text("(\(pc.name))").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            HStack(spacing: 6) {
                                Image(systemName: "heart.fill").foregroundStyle(hpColor(pc)).font(.caption)
                                Text("\(pc.currentHP)/\(pc.maxHP)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            TextField("+HP", text: Binding(
                                get: { hpEntries[pc.id] ?? "" },
                                set: { hpEntries[pc.id] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                            .frame(width: 72)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 320)

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
            .padding(20)
        }
        .frame(width: 480)
    }

    private func hpColor(_ pc: PlayerCharacter) -> Color {
        let pct = Double(pc.currentHP) / Double(max(1, pc.maxHP))
        if pct > 0.5 { return .green }
        if pct > 0.25 { return .yellow }
        return .red
    }

    private func applyShortRest() {
        for pc in characters {
            if let text = hpEntries[pc.id], let hp = Int(text), hp > 0 {
                pc.currentHP = min(pc.maxHP, pc.currentHP + hp)
            }
            var rs = pc.resources
            for i in rs.indices where rs[i].restType == .shortRest {
                rs[i].currentValue = rs[i].maxValue
            }
            pc.resources = rs
        }
        dismiss()
    }
}
