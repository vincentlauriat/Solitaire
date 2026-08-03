import SwiftUI

// MARK: - Carte (recto/verso avec flip 3D)

struct CardView: View {
    let card: Card
    let width: CGFloat
    var isLifted: Bool = false

    private var height: CGFloat { width / Theme.cardAspect }

    var body: some View {
        ZStack {
            CardBackView(width: width)
                .opacity(card.faceUp ? 0 : 1)
            CardFrontView(card: card, width: width)
                .opacity(card.faceUp ? 1 : 0)
        }
        .rotation3DEffect(.degrees(card.faceUp ? 0 : 180),
                          axis: (x: 0, y: 1, z: 0), perspective: 0.35)
        .animation(.spring(response: 0.38, dampingFraction: 0.85), value: card.faceUp)
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(isLifted ? 0.45 : 0.30),
                radius: isLifted ? width * 0.10 : width * 0.030,
                y: isLifted ? width * 0.07 : width * 0.022)
    }
}

// MARK: - Recto

struct CardFrontView: View {
    let card: Card
    let width: CGFloat

    private var height: CGFloat { width / Theme.cardAspect }
    private var corner: CGFloat { width * 0.09 }
    private var suitColor: Color { card.suit.isRed ? Theme.suitRed : Theme.suitBlack }

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(LinearGradient(colors: [Color(red: 1, green: 1, blue: 0.99),
                                          Color(red: 0.965, green: 0.955, blue: 0.935)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.10), lineWidth: 0.8)
            )
            .overlay(alignment: .topLeading) { cornerIndex }
            .overlay(alignment: .bottomTrailing) { cornerIndex.rotationEffect(.degrees(180)) }
            .overlay { centerContent }
            .frame(width: width, height: height)
    }

    private var cornerIndex: some View {
        VStack(spacing: -width * 0.012) {
            Text(card.rank.label)
                .font(.system(size: width * 0.175, weight: .semibold, design: .serif))
            Text(card.suit.symbol)
                .font(.system(size: width * 0.145))
        }
        .foregroundStyle(suitColor)
        .padding(.horizontal, width * 0.055)
        .padding(.vertical, width * 0.040)
    }

    @ViewBuilder
    private var centerContent: some View {
        if card.rank == .ace {
            Text(card.suit.symbol)
                .font(.system(size: width * 0.46))
                .foregroundStyle(suitColor)
        } else if card.rank.isFace {
            FaceCardView(card: card, width: width)
        } else {
            PipLayoutView(card: card, width: width)
                .frame(width: width * 0.56, height: height * 0.64)
        }
    }
}

// MARK: - Pips (positions classiques)

private struct PipLayoutView: View {
    let card: Card
    let width: CGFloat

    private var suitColor: Color { card.suit.isRed ? Theme.suitRed : Theme.suitBlack }

    private static let leftX: CGFloat = 0.18
    private static let midX: CGFloat = 0.5
    private static let rightX: CGFloat = 0.82

    private static func layout(for rank: Rank) -> [CGPoint] {
        let l = leftX, c = midX, r = rightX
        switch rank {
        case .two:   return [CGPoint(x: c, y: 0.08), CGPoint(x: c, y: 0.92)]
        case .three: return [CGPoint(x: c, y: 0.08), CGPoint(x: c, y: 0.50), CGPoint(x: c, y: 0.92)]
        case .four:  return [CGPoint(x: l, y: 0.08), CGPoint(x: r, y: 0.08),
                             CGPoint(x: l, y: 0.92), CGPoint(x: r, y: 0.92)]
        case .five:  return layout(for: .four) + [CGPoint(x: c, y: 0.50)]
        case .six:   return [CGPoint(x: l, y: 0.08), CGPoint(x: r, y: 0.08),
                             CGPoint(x: l, y: 0.50), CGPoint(x: r, y: 0.50),
                             CGPoint(x: l, y: 0.92), CGPoint(x: r, y: 0.92)]
        case .seven: return layout(for: .six) + [CGPoint(x: c, y: 0.29)]
        case .eight: return layout(for: .six) + [CGPoint(x: c, y: 0.29), CGPoint(x: c, y: 0.71)]
        case .nine:  return [CGPoint(x: l, y: 0.08), CGPoint(x: r, y: 0.08),
                             CGPoint(x: l, y: 0.36), CGPoint(x: r, y: 0.36),
                             CGPoint(x: l, y: 0.64), CGPoint(x: r, y: 0.64),
                             CGPoint(x: l, y: 0.92), CGPoint(x: r, y: 0.92),
                             CGPoint(x: c, y: 0.50)]
        case .ten:   return [CGPoint(x: l, y: 0.08), CGPoint(x: r, y: 0.08),
                             CGPoint(x: l, y: 0.36), CGPoint(x: r, y: 0.36),
                             CGPoint(x: l, y: 0.64), CGPoint(x: r, y: 0.64),
                             CGPoint(x: l, y: 0.92), CGPoint(x: r, y: 0.92),
                             CGPoint(x: c, y: 0.22), CGPoint(x: c, y: 0.78)]
        default:     return []
        }
    }

    var body: some View {
        let pipSize = width * (card.rank.rawValue >= 9 ? 0.185 : 0.215)
        GeometryReader { geo in
            ForEach(Array(Self.layout(for: card.rank).enumerated()), id: \.offset) { _, point in
                Text(card.suit.symbol)
                    .font(.system(size: pipSize))
                    .foregroundStyle(suitColor)
                    .rotationEffect(point.y > 0.5 ? .degrees(180) : .zero)
                    .position(x: point.x * geo.size.width, y: point.y * geo.size.height)
            }
        }
    }
}

// MARK: - Figures (V / D / R)

private struct FaceCardView: View {
    let card: Card
    let width: CGFloat

    private var height: CGFloat { width / Theme.cardAspect }
    private var suitColor: Color { card.suit.isRed ? Theme.suitRed : Theme.suitBlack }

    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.05, style: .continuous)
            .fill(suitColor.opacity(0.055))
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.05, style: .continuous)
                    .strokeBorder(suitColor.opacity(0.55), lineWidth: 1.1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.035, style: .continuous)
                    .strokeBorder(Theme.gold.opacity(0.85), lineWidth: 0.9)
                    .padding(width * 0.028)
            )
            .overlay {
                VStack(spacing: height * 0.015) {
                    Text(card.suit.symbol)
                        .font(.system(size: width * 0.14))
                    Text(card.rank.label)
                        .font(.system(size: width * 0.40, weight: .medium, design: .serif))
                        .italic()
                    Text(card.suit.symbol)
                        .font(.system(size: width * 0.14))
                        .rotationEffect(.degrees(180))
                }
                .foregroundStyle(suitColor)
            }
            .frame(width: width * 0.60, height: height * 0.64)
    }
}

// MARK: - Verso

struct CardBackView: View {
    let width: CGFloat

    private var height: CGFloat { width / Theme.cardAspect }
    private var corner: CGFloat { width * 0.09 }

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(LinearGradient(colors: [Theme.backNavy, Theme.backNavyDeep],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Canvas { context, size in
                    let inset: CGFloat = width * 0.10
                    let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
                    let clip = Path(roundedRect: rect, cornerRadius: width * 0.035)
                    context.clip(to: clip)
                    let step = width * 0.115
                    var lattice = Path()
                    var x = rect.minX - rect.height
                    while x < rect.maxX {
                        lattice.move(to: CGPoint(x: x, y: rect.minY))
                        lattice.addLine(to: CGPoint(x: x + rect.height, y: rect.maxY))
                        lattice.move(to: CGPoint(x: x + rect.height, y: rect.minY))
                        lattice.addLine(to: CGPoint(x: x, y: rect.maxY))
                        x += step
                    }
                    context.stroke(lattice, with: .color(Theme.gold.opacity(0.32)), lineWidth: 0.8)
                }
            }
            .overlay {
                Circle()
                    .fill(Theme.backNavyDeep)
                    .overlay(Circle().strokeBorder(Theme.gold.opacity(0.85), lineWidth: 1.0))
                    .overlay(
                        Text("♠")
                            .font(.system(size: width * 0.20))
                            .foregroundStyle(Theme.gold.opacity(0.9))
                    )
                    .frame(width: width * 0.34, height: width * 0.34)
            }
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.055, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.65), lineWidth: 1.1)
                    .padding(width * 0.045)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.25), lineWidth: 0.8)
            )
            .frame(width: width, height: height)
    }
}
