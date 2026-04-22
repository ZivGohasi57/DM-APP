import SwiftUI
import SwiftData

// MARK: - XPIndexView

struct XPIndexView: View {
    let campaign: Campaign

    @Query private var countries: [Country]
    @Query private var cities: [City]
    @Query private var stories: [Story]
    @Query private var encounters: [SavedEncounter]
    @Query private var monsters: [MonsterTemplate]
    @Query private var pcs: [PlayerCharacter]

    init(campaign: Campaign) {
        self.campaign = campaign
        let cid = campaign.id
        _countries = Query(filter: #Predicate<Country>         { $0.campaignID == cid },
                           sort: [SortDescriptor(\Country.sortOrder), SortDescriptor(\Country.name)])
        _cities    = Query(filter: #Predicate<City>            { $0.campaignID == cid })
        _stories   = Query(filter: #Predicate<Story>           { $0.campaignID == cid })
        _encounters = Query(filter: #Predicate<SavedEncounter> { $0.campaignID == cid })
        _monsters  = Query(filter: #Predicate<MonsterTemplate> { t in t.isGlobal || t.campaignID == cid })
        _pcs       = Query(filter: #Predicate<PlayerCharacter> { $0.campaignID == cid },
                           sort: [SortDescriptor(\PlayerCharacter.name)])
    }

    // MARK: - Lookups

    private var encounterXPMap: [UUID: Int] {
        let templateXP: [UUID: Int] = Dictionary(uniqueKeysWithValues: monsters.map { ($0.id, $0.challengeRating.xp) })
        return Dictionary(uniqueKeysWithValues: encounters.map { enc in
            let xp = enc.monsterEntries.reduce(0) { $0 + ($1.count * (templateXP[$1.templateID] ?? 0)) }
            return (enc.id, xp)
        })
    }

    private func storyTotalXP(_ story: Story) -> Int {
        let map = encounterXPMap
        let combatXP = story.linkedEncounters.reduce(0) { $0 + (map[$1.encounterID] ?? 0) }
        return story.rewardXP + combatXP
    }

    // MARK: - Aggregates

    private struct QuestTypeXP {
        var questXP: Int
        var combatXP: Int
        var total: Int { questXP + combatXP }
    }

    private func aggregate(stories: [Story]) -> QuestTypeXP {
        let map = encounterXPMap
        let questXP  = stories.reduce(0) { $0 + $1.rewardXP }
        let combatXP = stories.reduce(0) { acc, s in
            acc + s.linkedEncounters.reduce(0) { $0 + (map[$1.encounterID] ?? 0) }
        }
        return QuestTypeXP(questXP: questXP, combatXP: combatXP)
    }

    private var allMain: [Story] { stories.filter {  $0.isMainQuest } }
    private var allSide: [Story] { stories.filter { !$0.isMainQuest } }
    private var mainAgg: QuestTypeXP { aggregate(stories: allMain) }
    private var sideAgg: QuestTypeXP { aggregate(stories: allSide) }
    private var grandTotal: Int { mainAgg.total + sideAgg.total }

    // MARK: - Level table data

    private struct LevelRow {
        var level: Int
        var xp: Int
        var profBonus: Int
        var xpToNext: Int?
    }

    private static let levelRows: [LevelRow] = [
        LevelRow(level: 1,  xp: 0,       profBonus: 2, xpToNext: 300),
        LevelRow(level: 2,  xp: 300,     profBonus: 2, xpToNext: 600),
        LevelRow(level: 3,  xp: 900,     profBonus: 2, xpToNext: 1_800),
        LevelRow(level: 4,  xp: 2_700,   profBonus: 2, xpToNext: 3_800),
        LevelRow(level: 5,  xp: 6_500,   profBonus: 3, xpToNext: 7_500),
        LevelRow(level: 6,  xp: 14_000,  profBonus: 3, xpToNext: 9_000),
        LevelRow(level: 7,  xp: 23_000,  profBonus: 3, xpToNext: 11_000),
        LevelRow(level: 8,  xp: 34_000,  profBonus: 3, xpToNext: 14_000),
        LevelRow(level: 9,  xp: 48_000,  profBonus: 4, xpToNext: 16_000),
        LevelRow(level: 10, xp: 64_000,  profBonus: 4, xpToNext: 21_000),
        LevelRow(level: 11, xp: 85_000,  profBonus: 4, xpToNext: 15_000),
        LevelRow(level: 12, xp: 100_000, profBonus: 4, xpToNext: 20_000),
        LevelRow(level: 13, xp: 120_000, profBonus: 5, xpToNext: 20_000),
        LevelRow(level: 14, xp: 140_000, profBonus: 5, xpToNext: 25_000),
        LevelRow(level: 15, xp: 165_000, profBonus: 5, xpToNext: 30_000),
        LevelRow(level: 16, xp: 195_000, profBonus: 5, xpToNext: 30_000),
        LevelRow(level: 17, xp: 225_000, profBonus: 6, xpToNext: 40_000),
        LevelRow(level: 18, xp: 265_000, profBonus: 6, xpToNext: 40_000),
        LevelRow(level: 19, xp: 305_000, profBonus: 6, xpToNext: 50_000),
        LevelRow(level: 20, xp: 355_000, profBonus: 6, xpToNext: nil),
    ]

    // MARK: - Country breakdown

    private struct CountryStat: Identifiable {
        var id: UUID { country.id }
        var country: Country
        var main: QuestTypeXP
        var side: QuestTypeXP
        var total: Int { main.total + side.total }
    }

    private var countryStats: [CountryStat] {
        let cityByID = Dictionary(uniqueKeysWithValues: cities.map { ($0.id, $0) })
        return countries.compactMap { country in
            let citiesOfCountry = cities.filter { $0.countryID == country.id }
            let cityIDs = Set(citiesOfCountry.map { $0.id })
            let cs = stories.filter { s in
                guard let cid = s.locationCityID else { return false }
                return cityIDs.contains(cid)
            }
            guard !cs.isEmpty else { return nil }
            let _ = cityByID
            return CountryStat(
                country: country,
                main: aggregate(stories: cs.filter {  $0.isMainQuest }),
                side: aggregate(stories: cs.filter { !$0.isMainQuest })
            )
        }
    }

    private var unlocatedStories: [Story] {
        let cityIDs = Set(cities.map { $0.id })
        return stories.filter { s in
            guard let cid = s.locationCityID else { return true }
            return !cityIDs.contains(cid)
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard
                if !countryStats.isEmpty {
                    Text("By Country")
                        .font(.title3.bold())
                        .padding(.horizontal, 24)
                    ForEach(countryStats) { stat in
                        countryCard(stat)
                    }
                }
                let unlocMain = aggregate(stories: unlocatedStories.filter {  $0.isMainQuest })
                let unlocSide = aggregate(stories: unlocatedStories.filter { !$0.isMainQuest })
                if unlocMain.total + unlocSide.total > 0 {
                    noLocationCard(main: unlocMain, side: unlocSide)
                }

                Divider()
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                Text("Level Progression")
                    .font(.title3.bold())
                    .padding(.horizontal, 24)

                levelTableCard
                    .padding(.bottom, 8)
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("XP Index")
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                summaryColumn(
                    label: "Main Quests",
                    icon: "crown.fill",
                    color: .red,
                    agg: mainAgg
                )
                Divider()
                summaryColumn(
                    label: "Side Quests",
                    icon: "signpost.right.fill",
                    color: .teal,
                    agg: sideAgg
                )
                Divider()
                VStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                    Text("\(grandTotal)")
                        .font(.title2.monospacedDigit().bold())
                    Text("Grand Total")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text("XP")
                        .font(.caption2.bold()).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1))
        .padding(.horizontal, 24)
    }

    private func summaryColumn(label: String, icon: String, color: Color, agg: QuestTypeXP) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text("\(agg.total)")
                .font(.title2.monospacedDigit().bold())
            Text(label)
                .font(.caption2).foregroundStyle(.secondary)
            Divider().padding(.horizontal, 12)
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("\(agg.questXP)")
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(.orange)
                    Text("Quest")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text("\(agg.combatXP)")
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(.purple)
                    Text("Combat")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    // MARK: - Country card

    private func countryCard(_ stat: CountryStat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(stat.country.name, systemImage: "map.fill")
                    .font(.headline)
                Spacer()
                Text("\(stat.total) XP")
                    .font(.callout.monospacedDigit().bold())
            }

            HStack(spacing: 0) {
                countryRow(label: "Main", icon: "crown.fill", color: .red, agg: stat.main)
                Divider().frame(height: 40).padding(.horizontal, 8)
                countryRow(label: "Side", icon: "signpost.right.fill", color: .teal, agg: stat.side)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1))
        .padding(.horizontal, 24)
    }

    // MARK: - Level table card

    @State private var hoveredLevel: Int? = nil

    private var levelTableCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tableHeaderCell("Level",         alignment: .center)
                colDivider
                tableHeaderCell("Players",       alignment: .center)
                colDivider
                tableHeaderCell("XP Required",   alignment: .center)
                colDivider
                tableHeaderCell("Prof Bonus",    alignment: .center)
                colDivider
                tableHeaderCell("XP to Next Lv", alignment: .center)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.07))

            Divider()

            ForEach(Self.levelRows, id: \.level) { row in
                let pcsAtLevel = pcs.filter { $0.level == row.level }
                HStack(spacing: 0) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 8))
                            .foregroundStyle(levelColor(row.level))
                        Text("\(row.level)")
                            .font(.callout.monospacedDigit().bold())
                            .foregroundStyle(levelColor(row.level))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    colDivider

                    HStack(spacing: 4) {
                        ForEach(pcsAtLevel) { pc in
                            Text(pc.combatSymbol.isEmpty ? "?" : pc.combatSymbol)
                                .font(.system(size: 15))
                                .help(pc.playerName.isEmpty ? pc.name : pc.playerName)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    colDivider

                    Text(row.xp == 0 ? "—" : formatXP(row.xp))
                        .font(.callout.monospacedDigit())
                        .frame(maxWidth: .infinity, alignment: .center)

                    colDivider

                    Text("+\(row.profBonus)")
                        .font(.callout.monospacedDigit().bold())
                        .foregroundStyle(.teal)
                        .frame(maxWidth: .infinity, alignment: .center)

                    colDivider

                    Group {
                        if let next = row.xpToNext {
                            Text(formatXP(next)).foregroundStyle(.orange)
                        } else {
                            Text("—").foregroundStyle(.secondary)
                        }
                    }
                    .font(.callout.monospacedDigit())
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(hoveredLevel == row.level ? Color.secondary.opacity(0.08) : Color.clear)
                .onHover { hoveredLevel = $0 ? row.level : nil }

                if row.level != Self.levelRows.last?.level {
                    Divider()
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1))
        .padding(.horizontal, 24)
    }

    private var colDivider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 1)
            .padding(.vertical, 2)
    }

    private func tableHeaderCell(_ label: String, alignment: Alignment) -> some View {
        Text(label)
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func levelColor(_ level: Int) -> Color {
        switch level {
        case 1...4:   return .green
        case 5...10:  return .blue
        case 11...16: return .purple
        default:      return .orange
        }
    }

    private func formatXP(_ xp: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: xp)) ?? "\(xp)") + " XP"
    }

    private func countryRow(label: String, icon: String, color: Color, agg: QuestTypeXP) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption).foregroundStyle(color)
            Text(label).font(.caption.bold()).foregroundStyle(.secondary)
            Spacer()
            if agg.total == 0 {
                Text("—").font(.callout).foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(agg.total) XP")
                        .font(.callout.monospacedDigit().bold())
                    HStack(spacing: 6) {
                        if agg.questXP > 0 {
                            Text("\(agg.questXP) quest")
                                .font(.caption2).foregroundStyle(.orange)
                        }
                        if agg.combatXP > 0 {
                            Text("\(agg.combatXP) combat")
                                .font(.caption2).foregroundStyle(.purple)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - No location card

    private func noLocationCard(main: QuestTypeXP, side: QuestTypeXP) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("No Location", systemImage: "questionmark.circle.fill")
                    .font(.headline).foregroundStyle(.secondary)
                Spacer()
                Text("\(main.total + side.total) XP")
                    .font(.callout.monospacedDigit().bold())
            }
            HStack(spacing: 0) {
                countryRow(label: "Main", icon: "crown.fill", color: .red, agg: main)
                Divider().frame(height: 40).padding(.horizontal, 8)
                countryRow(label: "Side", icon: "signpost.right.fill", color: .teal, agg: side)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1))
        .padding(.horizontal, 24)
    }
}
