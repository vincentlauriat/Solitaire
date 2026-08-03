import Foundation

enum Suit: String, CaseIterable, Hashable {
    case spades, hearts, diamonds, clubs

    var symbol: String {
        switch self {
        case .spades: return "♠"
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .clubs: return "♣"
        }
    }

    var isRed: Bool { self == .hearts || self == .diamonds }
}

enum Rank: Int, CaseIterable, Hashable, Comparable {
    case ace = 1, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king

    var label: String {
        switch self {
        case .ace: return "A"
        case .jack: return "V"
        case .queen: return "D"
        case .king: return "R"
        default: return String(rawValue)
        }
    }

    var isFace: Bool { self == .jack || self == .queen || self == .king }

    static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct Card: Identifiable, Hashable {
    let suit: Suit
    let rank: Rank
    var faceUp: Bool = false

    var id: String { "\(suit.rawValue)-\(rank.rawValue)" }

    static func fullDeck() -> [Card] {
        Suit.allCases.flatMap { suit in
            Rank.allCases.map { Card(suit: suit, rank: $0) }
        }
    }
}
