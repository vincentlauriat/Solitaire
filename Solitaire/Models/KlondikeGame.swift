import SwiftUI

enum PileID: Hashable {
    case stock
    case waste
    case foundation(Int)
    case tableau(Int)
}

@MainActor
final class KlondikeGame: ObservableObject {
    @Published private(set) var stock: [Card] = []
    @Published private(set) var waste: [Card] = []
    @Published private(set) var foundations: [[Card]] = Array(repeating: [], count: 4)
    @Published private(set) var tableau: [[Card]] = Array(repeating: [], count: 7)

    @Published private(set) var score = 0
    @Published private(set) var moves = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var isWon = false
    @Published private(set) var isDealing = false
    @Published private(set) var hasStarted = false

    @Published var drawThree: Bool {
        didSet { UserDefaults.standard.set(drawThree, forKey: "drawThree") }
    }

    private struct Snapshot {
        let stock: [Card]
        let waste: [Card]
        let foundations: [[Card]]
        let tableau: [[Card]]
        let score: Int
        let moves: Int
    }

    private var undoStack: [Snapshot] = []
    private var dealTask: Task<Void, Never>?
    private var hasDealtOnce = false

    var canUndo: Bool { !undoStack.isEmpty && !isDealing && !isWon }

    private var clock: Timer?

    init() {
        drawThree = UserDefaults.standard.bool(forKey: "drawThree")
        clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    deinit {
        clock?.invalidate()
    }

    // MARK: - Nouvelle partie

    func startIfNeeded() {
        guard !hasDealtOnce else { return }
        hasDealtOnce = true
        newGame()
    }

    func newGame() {
        dealTask?.cancel()
        stock = Card.fullDeck().shuffled()
        waste = []
        foundations = Array(repeating: [], count: 4)
        tableau = Array(repeating: [], count: 7)
        score = 0
        moves = 0
        elapsed = 0
        isWon = false
        hasStarted = false
        undoStack = []
        isDealing = true

        dealTask = Task { [weak self] in
            guard let self else { return }
            for column in 0..<7 {
                for row in 0...column {
                    try? await Task.sleep(nanoseconds: 32_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                        guard var card = self.stock.popLast() else { return }
                        card.faceUp = (row == column)
                        self.tableau[column].append(card)
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
            self.isDealing = false
        }
    }

    func tick() {
        guard hasStarted, !isWon, !isDealing else { return }
        elapsed += 1
    }

    // MARK: - Pioche

    func draw() {
        guard !isDealing, !isWon else { return }
        pushUndo()
        hasStarted = true
        if stock.isEmpty {
            guard !waste.isEmpty else { undoStack.removeLast(); return }
            stock = waste.reversed().map { var c = $0; c.faceUp = false; return c }
            waste = []
            if !drawThree { score = max(0, score - 100) }
        } else {
            let count = min(drawThree ? 3 : 1, stock.count)
            for _ in 0..<count {
                var card = stock.removeLast()
                card.faceUp = true
                waste.append(card)
            }
        }
        moves += 1
    }

    // MARK: - Accès aux piles

    private func pile(_ id: PileID) -> [Card] {
        switch id {
        case .stock: return stock
        case .waste: return waste
        case .foundation(let i): return foundations[i]
        case .tableau(let i): return tableau[i]
        }
    }

    /// Cartes déplaçables en attrapant `card` dans la pile `id` (suffixe face visible).
    func draggableCards(from id: PileID, startingAt card: Card) -> [Card]? {
        guard !isDealing, !isWon else { return nil }
        switch id {
        case .stock:
            return nil
        case .waste, .foundation:
            guard let top = pile(id).last, top.id == card.id else { return nil }
            return [top]
        case .tableau(let i):
            guard let index = tableau[i].firstIndex(where: { $0.id == card.id }),
                  tableau[i][index].faceUp else { return nil }
            return Array(tableau[i][index...])
        }
    }

    func canDrop(_ cards: [Card], on target: PileID) -> Bool {
        guard let first = cards.first else { return false }
        switch target {
        case .stock, .waste:
            return false
        case .foundation(let i):
            guard cards.count == 1 else { return false }
            if let top = foundations[i].last {
                return top.suit == first.suit && top.rank.rawValue + 1 == first.rank.rawValue
            }
            return first.rank == .ace
        case .tableau(let i):
            if let top = tableau[i].last {
                return top.faceUp
                    && top.rank.rawValue == first.rank.rawValue + 1
                    && top.suit.isRed != first.suit.isRed
            }
            return first.rank == .king
        }
    }

    @discardableResult
    func move(_ cards: [Card], from source: PileID, to target: PileID) -> Bool {
        guard canDrop(cards, on: target),
              let firstID = cards.first?.id else { return false }
        pushUndo()
        hasStarted = true

        switch source {
        case .stock:
            undoStack.removeLast()
            return false
        case .waste:
            waste.removeLast(cards.count)
        case .foundation(let i):
            foundations[i].removeLast(cards.count)
        case .tableau(let i):
            guard let index = tableau[i].firstIndex(where: { $0.id == firstID }) else {
                undoStack.removeLast()
                return false
            }
            tableau[i].removeSubrange(index...)
            if let lastIndex = tableau[i].indices.last, !tableau[i][lastIndex].faceUp {
                tableau[i][lastIndex].faceUp = true
                score += 5
            }
        }

        switch target {
        case .stock, .waste:
            break
        case .foundation(let i):
            foundations[i].append(contentsOf: cards)
            score += 10
        case .tableau(let i):
            tableau[i].append(contentsOf: cards)
            if case .waste = source { score += 5 }
            if case .foundation = source { score = max(0, score - 15) }
        }

        moves += 1
        checkWin()
        return true
    }

    /// Double-clic : tente d'envoyer la carte du dessus de `source` vers une fondation.
    @discardableResult
    func autoMoveToFoundation(from source: PileID) -> Bool {
        guard let top = pile(source).last, top.faceUp else { return false }
        for i in 0..<4 where canDrop([top], on: .foundation(i)) {
            return move([top], from: source, to: .foundation(i))
        }
        return false
    }

    // MARK: - Auto-complétion

    var canAutoComplete: Bool {
        !isWon && !isDealing && stock.isEmpty && waste.isEmpty
            && tableau.contains(where: { !$0.isEmpty })
            && tableau.allSatisfy { $0.allSatisfy(\.faceUp) }
    }

    func autoComplete() async {
        while !isWon {
            var moved = false
            // Toujours jouer la plus petite carte plaçable pour un déroulé naturel.
            let candidates = (0..<7)
                .compactMap { i -> (Int, Card)? in
                    guard let top = tableau[i].last else { return nil }
                    return (i, top)
                }
                .sorted { $0.1.rank < $1.1.rank }
            for (i, top) in candidates {
                for f in 0..<4 where canDrop([top], on: .foundation(f)) {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                        _ = move([top], from: .tableau(i), to: .foundation(f))
                    }
                    moved = true
                    break
                }
                if moved { break }
            }
            guard moved else { return }
            try? await Task.sleep(nanoseconds: 110_000_000)
        }
    }

    // MARK: - Undo

    private func pushUndo() {
        undoStack.append(Snapshot(stock: stock, waste: waste, foundations: foundations,
                                  tableau: tableau, score: score, moves: moves))
        if undoStack.count > 200 { undoStack.removeFirst() }
    }

    func undo() {
        guard canUndo, let snapshot = undoStack.popLast() else { return }
        stock = snapshot.stock
        waste = snapshot.waste
        foundations = snapshot.foundations
        tableau = snapshot.tableau
        score = snapshot.score
        moves = snapshot.moves
    }

    private func checkWin() {
        if foundations.reduce(0, { $0 + $1.count }) == 52 {
            isWon = true
        }
    }
}
