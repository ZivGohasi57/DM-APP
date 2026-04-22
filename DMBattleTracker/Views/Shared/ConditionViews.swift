import SwiftUI

struct AddConditionView: View {
    var combatant: Combatant
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCondition: ConditionType = .blinded
    @State private var hasDuration: Bool = false
    @State private var durationRounds: Int = 1
    @State private var exhaustionLevel: Int = 1
    @State private var endOnSave: Bool = false

    private var supportsSave: Bool {
        ActiveCondition.saveConditions.contains(selectedCondition)
    }

    var isImmune: Bool { combatant.isImmune(to: selectedCondition) }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Image(systemName: "cross.circle.fill")
                    .font(.system(size: 32)).foregroundStyle(.orange)
                Text("Add Condition to \(combatant.name)").font(.title2.bold())
            }
            .padding(.top, 24).padding(.bottom, 16)
            Divider()

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Condition")
                        .font(.callout.bold())
                        .foregroundStyle(.secondary)
                    Picker("", selection: $selectedCondition) {
                        ForEach(ConditionType.allCases) { c in
                            Label(c.rawValue, systemImage: c.systemImage).tag(c)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isImmune {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.shield.fill")
                                .foregroundStyle(.red)
                            Text("\(combatant.name) is immune to \(selectedCondition.rawValue).")
                                .font(.subheadline.bold())
                                .foregroundStyle(.red)
                        }
                        .padding(10)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Text(selectedCondition.effectDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)

                        if selectedCondition == .exhaustion {
                            HStack(spacing: 12) {
                                Text("Exhaustion Level:")
                                    .font(.callout.bold())
                                    .foregroundStyle(.secondary)
                                Stepper("\(exhaustionLevel)", value: $exhaustionLevel, in: 1...6)
                                    .labelsHidden()
                                Text("\(exhaustionLevel)")
                                    .font(.callout.bold())
                                    .frame(width: 20)
                            }
                        }
                    }
                }

                if !isImmune {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Duration")
                            .font(.callout.bold())
                            .foregroundStyle(.secondary)
                        Toggle("Set Duration (in Rounds)", isOn: $hasDuration)
                            .toggleStyle(.switch)
                        if hasDuration {
                            HStack(spacing: 12) {
                                Stepper("\(durationRounds) round\(durationRounds == 1 ? "" : "s")", value: $durationRounds, in: 1...100)
                                    .labelsHidden()
                                Text("\(durationRounds) round\(durationRounds == 1 ? "" : "s") (\(durationRounds * 6)s)")
                                    .font(.subheadline)
                            }
                        } else {
                            Text("Permanent — remove manually")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if supportsSave {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Saving throw at end of turn", isOn: $endOnSave)
                                .toggleStyle(.switch)
                            Text("Each round when this combatant's turn ends, you'll be prompted to resolve their saving throw.")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                        .onChange(of: selectedCondition) { _, _ in
                            endOnSave = false
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)

            Spacer(minLength: 20)
            Divider()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button("Add Condition") {
                    combatant.addCondition(
                        selectedCondition,
                        duration: hasDuration ? durationRounds : nil,
                        exhaustionLevel: exhaustionLevel,
                        endOnSave: endOnSave
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .keyboardShortcut(.defaultAction)
                .disabled(isImmune)
            }
            .padding(20)
        }
        .frame(width: 460, height: 380)
    }
}

struct ConditionImmunityGrid: View {
    @Binding var immunities: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if immunities.isEmpty {
                Text("No condition immunities.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(ConditionType.allCases) { condition in
                    let isImmune = immunities.contains(condition.rawValue)
                    Button {
                        if isImmune {
                            immunities.removeAll { $0 == condition.rawValue }
                        } else {
                            immunities.append(condition.rawValue)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isImmune ? "xmark.shield.fill" : condition.systemImage)
                                .font(.caption)
                                .foregroundStyle(isImmune ? .white : .secondary)
                            Text(condition.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(isImmune ? .white : .primary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 8)
                        .background(isImmune ? Color.red.opacity(0.75) : Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(isImmune ? Color.red : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct ConditionBadge: View {
    let condition: ActiveCondition
    var combatant: Combatant
    @State private var showPopover: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: condition.conditionType.systemImage)
                .font(.caption)

            Text(condition.conditionType.rawValue)
                .font(.caption.bold())

            if condition.conditionType == .exhaustion {
                Text("L\(condition.exhaustionLevel)")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }

            Text(condition.displayDuration)
                .font(.caption)
                .foregroundStyle(.secondary)

            if condition.conditionType == .prone {
                Button {
                    combatant.removeCondition(id: condition.id)
                } label: {
                    Text("Stand Up")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Spend half movement to stand up (removes Prone)")
            } else if condition.conditionType == .grappled || condition.conditionType == .restrained {
                Button {
                    combatant.removeCondition(id: condition.id)
                } label: {
                    Text("Escape")
                        .font(.caption.bold())
                        .foregroundStyle(.brown)
                }
                .buttonStyle(.plain)
                .help("Escape attempt succeeded — remove condition")
            } else {
                Button {
                    combatant.decrementConditionDuration(id: condition.id)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .help("Decrement duration by 1 round")
            }

            Button {
                combatant.removeCondition(id: condition.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Remove condition")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(conditionBadgeColor.opacity(0.15))
        .clipShape(Capsule())
        .onTapGesture { showPopover = true }
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: condition.conditionType.systemImage)
                        .foregroundStyle(conditionBadgeColor)
                        .font(.title3)
                    Text(condition.conditionType.rawValue)
                        .font(.headline)
                }
                Divider()
                Text(condition.conditionType.effectDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(18)
            .frame(minWidth: 340, maxWidth: 420)
        }
    }

    var conditionBadgeColor: Color {
        switch condition.conditionType {
        case .blinded, .invisible: return .purple
        case .charmed: return .pink
        case .deafened: return .gray
        case .exhaustion: return .orange
        case .frightened: return .yellow
        case .grappled, .restrained: return .brown
        case .incapacitated, .paralyzed, .stunned: return .red
        case .petrified: return .gray
        case .poisoned: return .green
        case .prone: return .secondary
        case .unconscious: return .indigo
        }
    }
}
