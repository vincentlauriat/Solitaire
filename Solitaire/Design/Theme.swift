import SwiftUI

enum Theme {
    static let feltLight = Color(red: 0.145, green: 0.435, blue: 0.310)
    static let feltDark = Color(red: 0.035, green: 0.180, blue: 0.125)
    static let gold = Color(red: 0.85, green: 0.72, blue: 0.42)
    static let suitRed = Color(red: 0.705, green: 0.110, blue: 0.150)
    static let suitBlack = Color(red: 0.125, green: 0.125, blue: 0.165)
    static let backNavy = Color(red: 0.105, green: 0.155, blue: 0.330)
    static let backNavyDeep = Color(red: 0.045, green: 0.075, blue: 0.185)
    static let cardAspect: CGFloat = 0.7
}

// MARK: - Tapis

struct FeltBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.feltLight, Theme.feltDark],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color.white.opacity(0.12), .clear],
                           center: UnitPoint(x: 0.5, y: 0.18),
                           startRadius: 20, endRadius: 720)
            RadialGradient(colors: [.clear, Color.black.opacity(0.42)],
                           center: .center, startRadius: 260, endRadius: 1100)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Emplacement vide

struct EmptySlotView: View {
    var width: CGFloat
    var symbol: String? = nil
    var systemImage: String? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.09, style: .continuous)
            .fill(Color.black.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.09, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1.2)
            )
            .overlay {
                if let symbol {
                    Text(symbol)
                        .font(.system(size: width * 0.42))
                        .foregroundStyle(Color.white.opacity(0.22))
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: width * 0.30, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.28))
                }
            }
            .frame(width: width, height: width / Theme.cardAspect)
    }
}

// MARK: - Confettis de victoire

struct ConfettiView: View {
    private struct Particle {
        let x: CGFloat
        let delay: Double
        let speed: Double
        let sway: CGFloat
        let swayFreq: Double
        let size: CGFloat
        let color: Color
        let spin: Double
    }

    private let particles: [Particle]
    private let startDate = Date()

    init() {
        let palette: [Color] = [Theme.gold, .white, Theme.suitRed,
                                Color(red: 0.35, green: 0.65, blue: 0.95),
                                Color(red: 0.55, green: 0.85, blue: 0.55)]
        particles = (0..<140).map { i in
            Particle(x: CGFloat.random(in: 0...1),
                     delay: Double.random(in: 0...2.5),
                     speed: Double.random(in: 130...300),
                     sway: CGFloat.random(in: 14...48),
                     swayFreq: Double.random(in: 1.2...2.8),
                     size: CGFloat.random(in: 5...11),
                     color: palette[i % palette.count],
                     spin: Double.random(in: 2...7))
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(startDate)
                for p in particles {
                    let life = t - p.delay
                    guard life > 0 else { continue }
                    let y = life * p.speed - 20
                    guard y < Double(size.height) + 30 else { continue }
                    let x = p.x * size.width + p.sway * CGFloat(sin(life * p.swayFreq))
                    var ctx = context
                    ctx.translateBy(x: x, y: CGFloat(y))
                    ctx.rotate(by: .radians(life * p.spin))
                    let rect = CGRect(x: -p.size / 2, y: -p.size / 2,
                                      width: p.size, height: p.size * 0.62)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1.2),
                             with: .color(p.color.opacity(0.92)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
