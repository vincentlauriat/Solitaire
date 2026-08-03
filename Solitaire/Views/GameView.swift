import SwiftUI

// MARK: - Métriques du plateau

struct BoardMetrics {
    let size: CGSize
    let hPad: CGFloat = 28
    let cardWidth: CGFloat
    let gap: CGFloat

    init(size: CGSize) {
        self.size = size
        let raw = (size.width - 56) / (7 + 6 * 0.16)
        cardWidth = min(132, max(58, raw))
        gap = cardWidth * 0.16
    }

    var cardHeight: CGFloat { cardWidth / Theme.cardAspect }
    var fanUp: CGFloat { cardHeight * 0.26 }
    var fanDown: CGFloat { cardHeight * 0.115 }
    var wasteFan: CGFloat { cardWidth * 0.30 }
    var rowGap: CGFloat { cardHeight * 0.13 }
    var headerHeight: CGFloat { 40 }
    var topPad: CGFloat { 16 }

    var tableauMaxHeight: CGFloat {
        max(cardHeight, size.height - topPad - headerHeight - rowGap * 2 - cardHeight - 20)
    }

    func tableauOffsets(_ cards: [Card]) -> [CGFloat] {
        guard cards.count > 1 else { return cards.map { _ in 0 } }
        var spacings: [CGFloat] = cards.dropLast().map { $0.faceUp ? fanUp : fanDown }
        let total = spacings.reduce(0, +)
        let available = tableauMaxHeight - cardHeight
        if total > available, total > 0 {
            let scale = available / total
            spacings = spacings.map { $0 * scale }
        }
        var offsets: [CGFloat] = [0]
        for s in spacings { offsets.append(offsets.last! + s) }
        return offsets
    }
}

// MARK: - Frames des piles (pour le drop)

struct PileFramesKey: PreferenceKey {
    static var defaultValue: [PileID: CGRect] = [:]
    static func reduce(value: inout [PileID: CGRect], nextValue: () -> [PileID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private extension View {
    func reportFrame(_ id: PileID) -> some View {
        background(GeometryReader { geo in
            Color.clear.preference(key: PileFramesKey.self,
                                   value: [id: geo.frame(in: .named("board"))])
        })
    }
}

// MARK: - Vue principale

struct GameView: View {
    @ObservedObject var game: KlondikeGame
    @Namespace private var cardSpace

    private struct DragInfo {
        var source: PileID
        var cards: [Card]
        var origin: CGPoint
        var translation: CGSize = .zero
    }

    @State private var drag: DragInfo?
    @State private var frames: [PileID: CGRect] = [:]

    var body: some View {
        GeometryReader { geo in
            let m = BoardMetrics(size: geo.size)
            ZStack(alignment: .topLeading) {
                FeltBackground()
                VStack(spacing: m.rowGap) {
                    header(m)
                    topRow(m)
                    tableauRow(m)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, m.hPad)
                .padding(.top, m.topPad)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)

                dragOverlay(m)

                if game.isWon {
                    ConfettiView()
                        .frame(width: geo.size.width, height: geo.size.height)
                    winBanner
                        .frame(width: geo.size.width, height: geo.size.height)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .coordinateSpace(name: "board")
            .onPreferenceChange(PileFramesKey.self) { frames = $0 }
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: game.isWon)
        }
    }

    // MARK: - Bandeau supérieur

    private func header(_ m: BoardMetrics) -> some View {
        HStack(spacing: 14) {
            Text("Solitaire")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(.white.opacity(0.92))
            Text("♠ ♥ ♦ ♣")
                .font(.system(size: 11))
                .foregroundStyle(Theme.gold.opacity(0.8))
            Spacer()
            statsCapsule
            Spacer()
            controls
        }
        .frame(height: m.headerHeight)
        .padding(.leading, 58)
    }

    private var statsCapsule: some View {
        HStack(spacing: 16) {
            stat(String(game.score), "score")
            statDivider
            stat(timeString(game.elapsed), "temps")
            statDivider
            stat(String(game.moves), "coups")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.10), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var statDivider: some View {
        Rectangle().fill(Color.white.opacity(0.15)).frame(width: 1, height: 22)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 8.5, weight: .medium))
                .textCase(.uppercase)
                .kerning(0.9)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(minWidth: 44)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            if game.canAutoComplete {
                roundButton("wand.and.stars", help: "Terminer automatiquement") {
                    Task { await game.autoComplete() }
                }
            }
            roundButton("arrow.uturn.backward", help: "Annuler (⌘Z)", disabled: !game.canUndo) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { game.undo() }
            }
            roundButton("shuffle", help: "Nouvelle partie (⌘N)") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { game.newGame() }
            }
            Menu {
                Toggle("Pioche par 3", isOn: $game.drawThree)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.10), in: Circle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private func roundButton(_ systemImage: String, help: String,
                             disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(disabled ? 0.3 : 0.9))
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.10), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
    }

    // MARK: - Rangée supérieure

    private func topRow(_ m: BoardMetrics) -> some View {
        HStack(alignment: .top, spacing: m.gap) {
            stockView(m)
            wasteView(m)
            Spacer(minLength: 0)
            ForEach(0..<4, id: \.self) { foundationView($0, m) }
        }
    }

    private func stockView(_ m: BoardMetrics) -> some View {
        ZStack {
            EmptySlotView(width: m.cardWidth, systemImage: "arrow.2.circlepath")
            ForEach(game.stock) { card in
                CardView(card: card, width: m.cardWidth)
                    .matchedGeometryEffect(id: card.id, in: cardSpace)
            }
        }
        .reportFrame(.stock)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) { game.draw() }
        }
    }

    private func wasteView(_ m: BoardMetrics) -> some View {
        let cards = game.waste
        return ZStack(alignment: .topLeading) {
            EmptySlotView(width: m.cardWidth)
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                cardCell(card, pile: .waste, m, isTop: index == cards.count - 1)
                    .offset(x: wasteXOffset(index: index, total: cards.count, m))
            }
        }
        .reportFrame(.waste)
    }

    private func foundationView(_ i: Int, _ m: BoardMetrics) -> some View {
        ZStack {
            EmptySlotView(width: m.cardWidth, symbol: "A")
            ForEach(Array(game.foundations[i].enumerated()), id: \.element.id) { index, card in
                cardCell(card, pile: .foundation(i), m,
                         isTop: index == game.foundations[i].count - 1)
            }
        }
        .reportFrame(.foundation(i))
    }

    // MARK: - Tableau

    private func tableauRow(_ m: BoardMetrics) -> some View {
        HStack(alignment: .top, spacing: m.gap) {
            ForEach(0..<7, id: \.self) { tableauColumn($0, m) }
        }
    }

    private func tableauColumn(_ i: Int, _ m: BoardMetrics) -> some View {
        let cards = game.tableau[i]
        let offsets = m.tableauOffsets(cards)
        return ZStack(alignment: .top) {
            EmptySlotView(width: m.cardWidth)
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                cardCell(card, pile: .tableau(i), m, isTop: index == cards.count - 1)
                    .offset(y: offsets[index])
            }
        }
        .frame(width: m.cardWidth, height: m.tableauMaxHeight, alignment: .top)
        .reportFrame(.tableau(i))
    }

    // MARK: - Cellule de carte (gestes communs)

    private func cardCell(_ card: Card, pile: PileID, _ m: BoardMetrics, isTop: Bool) -> some View {
        CardView(card: card, width: m.cardWidth)
            .matchedGeometryEffect(id: card.id, in: cardSpace)
            .opacity(isHidden(card) ? 0 : 1)
            .onTapGesture(count: 2) {
                guard isTop, card.faceUp else { return }
                _ = withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                    game.autoMoveToFoundation(from: pile)
                }
            }
            .gesture(dragGesture(for: card, in: pile, m))
    }

    private func isHidden(_ card: Card) -> Bool {
        drag?.cards.contains(where: { $0.id == card.id }) ?? false
    }

    // MARK: - Drag & drop

    private func dragGesture(for card: Card, in pile: PileID, _ m: BoardMetrics) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named("board"))
            .onChanged { value in
                if drag == nil {
                    guard let cards = game.draggableCards(from: pile, startingAt: card),
                          let origin = cardOrigin(of: card, in: pile, m) else { return }
                    drag = DragInfo(source: pile, cards: cards, origin: origin)
                }
                guard drag?.cards.first?.id == card.id else { return }
                drag?.translation = value.translation
            }
            .onEnded { _ in
                guard drag?.cards.first?.id == card.id else { return }
                endDrag(m)
            }
    }

    private func cardOrigin(of card: Card, in pile: PileID, _ m: BoardMetrics) -> CGPoint? {
        guard let frame = frames[pile] else { return nil }
        switch pile {
        case .stock:
            return nil
        case .waste:
            let total = game.waste.count
            return CGPoint(x: frame.minX + wasteXOffset(index: total - 1, total: total, m),
                           y: frame.minY)
        case .foundation:
            return CGPoint(x: frame.minX, y: frame.minY)
        case .tableau(let i):
            guard let index = game.tableau[i].firstIndex(where: { $0.id == card.id }) else { return nil }
            return CGPoint(x: frame.minX,
                           y: frame.minY + m.tableauOffsets(game.tableau[i])[index])
        }
    }

    private func wasteXOffset(index: Int, total: Int, _ m: BoardMetrics) -> CGFloat {
        guard game.drawThree, total > 0 else { return 0 }
        let start = total - min(3, total)
        guard index >= start else { return 0 }
        return CGFloat(index - start) * m.wasteFan
    }

    private func endDrag(_ m: BoardMetrics) {
        guard let d = drag else { return }
        let rect = CGRect(x: d.origin.x + d.translation.width,
                          y: d.origin.y + d.translation.height,
                          width: m.cardWidth, height: m.cardHeight)
        let targets: [PileID] = (0..<4).map { .foundation($0) } + (0..<7).map { .tableau($0) }
        var best: (pile: PileID, area: CGFloat)?
        for target in targets where target != d.source {
            guard let frame = frames[target], game.canDrop(d.cards, on: target) else { continue }
            let inter = frame.intersection(rect)
            guard !inter.isNull, inter.width > 0 else { continue }
            let area = inter.width * inter.height
            if area > (best?.area ?? 0) { best = (target, area) }
        }
        if let best {
            // Placement instantané : la carte est déjà visuellement à destination.
            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) { _ = game.move(d.cards, from: d.source, to: best.pile) }
            drag = nil
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                drag?.translation = .zero
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 330_000_000)
                drag = nil
            }
        }
    }

    @ViewBuilder
    private func dragOverlay(_ m: BoardMetrics) -> some View {
        if let d = drag {
            ZStack(alignment: .top) {
                ForEach(Array(d.cards.enumerated()), id: \.element.id) { index, card in
                    CardView(card: card, width: m.cardWidth, isLifted: true)
                        .offset(y: CGFloat(index) * m.fanUp)
                }
            }
            .offset(x: d.origin.x + d.translation.width,
                    y: d.origin.y + d.translation.height)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Victoire

    private var winBanner: some View {
        VStack(spacing: 12) {
            Text("♠ ♥ ♦ ♣")
                .font(.system(size: 15))
                .foregroundStyle(Theme.gold)
            Text("Bravo !")
                .font(.system(size: 36, weight: .bold, design: .serif))
                .foregroundStyle(.white)
            Text("Score \(game.score)  ·  \(timeString(game.elapsed))  ·  \(game.moves) coups")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { game.newGame() }
            } label: {
                Text("Nouvelle partie")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 9)
                    .background(Theme.gold, in: Capsule())
                    .foregroundStyle(Color.black.opacity(0.8))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(36)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Theme.gold.opacity(0.5), lineWidth: 1)
        )
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
