import Foundation

enum ChallengeRating: String, CaseIterable, Codable, Identifiable {
    case zero = "0"
    case oneEighth = "1/8"
    case oneQuarter = "1/4"
    case oneHalf = "1/2"
    case one = "1"
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case six = "6"
    case seven = "7"
    case eight = "8"
    case nine = "9"
    case ten = "10"
    case eleven = "11"
    case twelve = "12"
    case thirteen = "13"
    case fourteen = "14"
    case fifteen = "15"
    case sixteen = "16"
    case seventeen = "17"
    case eighteen = "18"
    case nineteen = "19"
    case twenty = "20"
    case twentyOne = "21"
    case twentyTwo = "22"
    case twentyThree = "23"
    case twentyFour = "24"
    case twentyFive = "25"
    case twentySix = "26"
    case twentySeven = "27"
    case twentyEight = "28"
    case twentyNine = "29"
    case thirty = "30"

    var id: String { rawValue }

    var xp: Int {
        switch self {
        case .zero: return 0
        case .oneEighth: return 25
        case .oneQuarter: return 50
        case .oneHalf: return 100
        case .one: return 200
        case .two: return 450
        case .three: return 700
        case .four: return 1100
        case .five: return 1800
        case .six: return 2300
        case .seven: return 2900
        case .eight: return 3900
        case .nine: return 5000
        case .ten: return 5900
        case .eleven: return 7200
        case .twelve: return 8400
        case .thirteen: return 10000
        case .fourteen: return 11500
        case .fifteen: return 13000
        case .sixteen: return 15000
        case .seventeen: return 18000
        case .eighteen: return 20000
        case .nineteen: return 22000
        case .twenty: return 25000
        case .twentyOne: return 33000
        case .twentyTwo: return 41000
        case .twentyThree: return 50000
        case .twentyFour: return 62000
        case .twentyFive: return 75000
        case .twentySix: return 90000
        case .twentySeven: return 105000
        case .twentyEight: return 120000
        case .twentyNine: return 135000
        case .thirty: return 155000
        }
    }

    var proficiencyBonus: Int {
        switch self {
        case .zero, .oneEighth, .oneQuarter, .oneHalf, .one, .two, .three, .four: return 2
        case .five, .six, .seven, .eight: return 3
        case .nine, .ten, .eleven, .twelve: return 4
        case .thirteen, .fourteen, .fifteen, .sixteen: return 5
        case .seventeen, .eighteen, .nineteen, .twenty: return 6
        case .twentyOne, .twentyTwo, .twentyThree, .twentyFour: return 7
        case .twentyFive, .twentySix, .twentySeven, .twentyEight: return 8
        case .twentyNine, .thirty: return 9
        }
    }

    static let levelThresholds: [(level: Int, xp: Int)] = [
        (1, 0), (2, 300), (3, 900), (4, 2700), (5, 6500),
        (6, 14000), (7, 23000), (8, 34000), (9, 48000), (10, 64000),
        (11, 85000), (12, 100000), (13, 120000), (14, 140000), (15, 165000),
        (16, 195000), (17, 225000), (18, 265000), (19, 305000), (20, 355000)
    ]

    static func levelForXP(_ xp: Int) -> Int {
        var result = 1
        for threshold in levelThresholds where xp >= threshold.xp {
            result = threshold.level
        }
        return result
    }

    static func xpForLevel(_ level: Int) -> Int {
        levelThresholds.first(where: { $0.level == level })?.xp ?? 0
    }

    static func xpForNextLevel(afterLevel level: Int) -> Int? {
        guard level < 20 else { return nil }
        return levelThresholds.first(where: { $0.level == level + 1 })?.xp
    }
}
