import Foundation

enum ConditionType: String, CaseIterable, Codable, Identifiable, Hashable {
    case blinded = "Blinded"
    case charmed = "Charmed"
    case deafened = "Deafened"
    case exhaustion = "Exhaustion"
    case frightened = "Frightened"
    case grappled = "Grappled"
    case incapacitated = "Incapacitated"
    case invisible = "Invisible"
    case paralyzed = "Paralyzed"
    case petrified = "Petrified"
    case poisoned = "Poisoned"
    case prone = "Prone"
    case restrained = "Restrained"
    case stunned = "Stunned"
    case unconscious = "Unconscious"

    var id: String { rawValue }

    var effectDescription: String {
        switch self {
        case .blinded:
            return "Can't see. Attacks against have advantage, own attacks have disadvantage."
        case .charmed:
            return "Can't attack charmer. Charmer has advantage on social checks against them."
        case .deafened:
            return "Can't hear. Fails hearing checks."
        case .exhaustion:
            return "Track 6 levels (1: Disadvantage ability checks; 2: Speed halved; 3: Disadvantage attacks/saves; 4: Max HP halved; 5: Speed 0; 6: Death)."
        case .frightened:
            return "Disadvantage on checks/attacks while source visible. Can't move closer to source."
        case .grappled:
            return "Speed 0. Ends if grappler is incapacitated."
        case .incapacitated:
            return "Can't take actions or reactions."
        case .invisible:
            return "Can't be seen. Attacks against have disadvantage, own attacks have advantage."
        case .paralyzed:
            return "Incapacitated, can't move/speak. Auto-fails Str/Dex saves. Attacks against have advantage. Hits from within 5ft are criticals."
        case .petrified:
            return "Turned to stone. Incapacitated. Auto-fails Str/Dex saves. Resistance to all damage. Immune to poison/disease."
        case .poisoned:
            return "Disadvantage on attack rolls and ability checks."
        case .prone:
            return "Can only crawl. Own attacks have disadvantage. Attacks against have advantage if within 5ft, disadvantage if further."
        case .restrained:
            return "Speed 0. Attacks against have advantage, own attacks have disadvantage. Disadvantage on Dex saves."
        case .stunned:
            return "Incapacitated, can't move. Auto-fails Str/Dex saves. Attacks against have advantage."
        case .unconscious:
            return "Incapacitated, drops items, falls prone. Auto-fails Str/Dex saves. Attacks against have advantage. Hits from within 5ft are criticals."
        }
    }

    var systemImage: String {
        switch self {
        case .blinded: return "eye.slash"
        case .charmed: return "heart.fill"
        case .deafened: return "ear.trianglebadge.exclamationmark"
        case .exhaustion: return "battery.25"
        case .frightened: return "exclamationmark.triangle.fill"
        case .grappled: return "hand.raised.fill"
        case .incapacitated: return "minus.circle.fill"
        case .invisible: return "eye.slash.fill"
        case .paralyzed: return "bolt.slash.fill"
        case .petrified: return "cube.fill"
        case .poisoned: return "cross.vial.fill"
        case .prone: return "arrow.down.circle.fill"
        case .restrained: return "lock.fill"
        case .stunned: return "star.circle.fill"
        case .unconscious: return "moon.zzz.fill"
        }
    }
}
