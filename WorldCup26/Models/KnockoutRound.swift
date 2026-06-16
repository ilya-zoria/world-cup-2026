import Foundation

/// The knockout phase rounds for the 48-team World Cup 2026 format.
enum KnockoutRound: String, Codable, CaseIterable, Identifiable, Hashable {
    case roundOf32 = "round_of_32"
    case roundOf16 = "round_of_16"
    case quarterFinal = "quarter_final"
    case semiFinal = "semi_final"
    case thirdPlace = "third_place"
    case final = "final"

    var id: String { rawValue }

    /// Display order left-to-right in the bracket.
    var order: Int {
        switch self {
        case .roundOf32: return 0
        case .roundOf16: return 1
        case .quarterFinal: return 2
        case .semiFinal: return 3
        case .thirdPlace: return 4
        case .final: return 5
        }
    }

    /// Rounds shown as bracket columns (third-place play-off is rendered separately).
    static var bracketColumns: [KnockoutRound] {
        [.roundOf32, .roundOf16, .quarterFinal, .semiFinal, .final]
    }

    var displayKey: String {
        switch self {
        case .roundOf32: return "round.r32"
        case .roundOf16: return "round.r16"
        case .quarterFinal: return "round.qf"
        case .semiFinal: return "round.sf"
        case .thirdPlace: return "round.third"
        case .final: return "round.final"
        }
    }

    var shortKey: String {
        switch self {
        case .roundOf32: return "round.r32.short"
        case .roundOf16: return "round.r16.short"
        case .quarterFinal: return "round.qf.short"
        case .semiFinal: return "round.sf.short"
        case .thirdPlace: return "round.third.short"
        case .final: return "round.final.short"
        }
    }
}
