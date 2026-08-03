#!/usr/bin/env swift
// Generates the Solitaire app icon set: two playing cards (navy back + ace of
// spades) fanned on a felt-green rounded square, matching the in-app theme.
// Usage: ./Scripts/make-app-icon.swift
import AppKit

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let root = scriptDir.deletingLastPathComponent()
let iconset = root.appendingPathComponent("Solitaire/Assets.xcassets/AppIcon.appiconset")
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let feltLight = NSColor(calibratedRed: 0.165, green: 0.475, blue: 0.340, alpha: 1)
let feltDark = NSColor(calibratedRed: 0.030, green: 0.160, blue: 0.110, alpha: 1)
let navy = NSColor(calibratedRed: 0.105, green: 0.155, blue: 0.330, alpha: 1)
let navyDeep = NSColor(calibratedRed: 0.045, green: 0.075, blue: 0.185, alpha: 1)
let gold = NSColor(calibratedRed: 0.85, green: 0.72, blue: 0.42, alpha: 1)
let ink = NSColor(calibratedRed: 0.125, green: 0.125, blue: 0.165, alpha: 1)

func serifFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
    let desc = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.serif)
    return desc.flatMap { NSFont(descriptor: $0, size: size) }
        ?? NSFont.systemFont(ofSize: size, weight: weight)
}

func render(_ size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Fond feutre arrondi + halo lumineux
    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    let bg = NSBezierPath(roundedRect: rect, xRadius: s * 0.22, yRadius: s * 0.22)
    NSGradient(colors: [feltLight, feltDark])!.draw(in: bg, angle: -90)
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.14), .clear])!
        .draw(in: bg, relativeCenterPosition: NSPoint(x: 0, y: 0.55))

    let cw = s * 0.44
    let ch = cw / 0.7
    let cr = cw * 0.10
    let cardRect = NSRect(x: -cw / 2, y: -ch / 2, width: cw, height: ch)

    func withTransform(dx: CGFloat, dy: CGFloat, degrees: CGFloat, _ draw: () -> Void) {
        NSGraphicsContext.current!.saveGraphicsState()
        let t = NSAffineTransform()
        t.translateX(by: s / 2 + dx, yBy: s / 2 + dy)
        t.rotate(byDegrees: degrees)
        t.concat()
        draw()
        NSGraphicsContext.current!.restoreGraphicsState()
    }

    func cardShadow() {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        shadow.shadowBlurRadius = s * 0.028
        shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
        shadow.set()
    }

    // Carte du dessous : dos bleu nuit, liseré or
    withTransform(dx: s * 0.085, dy: s * 0.02, degrees: -10) {
        cardShadow()
        let p = NSBezierPath(roundedRect: cardRect, xRadius: cr, yRadius: cr)
        navy.setFill()
        p.fill()
        NSShadow().set()
        NSGradient(colors: [navy, navyDeep])!.draw(in: p, angle: -75)
        let inner = NSBezierPath(roundedRect: cardRect.insetBy(dx: cw * 0.06, dy: cw * 0.06),
                                 xRadius: cr * 0.55, yRadius: cr * 0.55)
        inner.lineWidth = max(1, s * 0.008)
        gold.withAlphaComponent(0.85).setStroke()
        inner.stroke()
    }

    // Carte du dessus : as de pique
    withTransform(dx: -s * 0.075, dy: -s * 0.015, degrees: 8) {
        cardShadow()
        let p = NSBezierPath(roundedRect: cardRect, xRadius: cr, yRadius: cr)
        NSColor(calibratedWhite: 0.98, alpha: 1).setFill()
        p.fill()
        NSShadow().set()
        NSColor.black.withAlphaComponent(0.10).setStroke()
        p.lineWidth = max(1, s * 0.004)
        p.stroke()

        let para = NSMutableParagraphStyle()
        para.alignment = .center

        // ♠ central
        let pipAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: cw * 0.62),
            .foregroundColor: ink,
            .paragraphStyle: para,
        ]
        let pip = "♠" as NSString
        let pipSize = pip.size(withAttributes: pipAttrs)
        pip.draw(at: NSPoint(x: -pipSize.width / 2, y: -pipSize.height / 2 - ch * 0.015),
                 withAttributes: pipAttrs)

        // Index de coin "A♠"
        let rankAttrs: [NSAttributedString.Key: Any] = [
            .font: serifFont(size: cw * 0.20, weight: .semibold),
            .foregroundColor: ink,
        ]
        ("A" as NSString).draw(at: NSPoint(x: -cw / 2 + cw * 0.075, y: ch / 2 - cw * 0.30),
                               withAttributes: rankAttrs)
        let smallPipAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: cw * 0.15),
            .foregroundColor: ink,
        ]
        ("♠" as NSString).draw(at: NSPoint(x: -cw / 2 + cw * 0.075, y: ch / 2 - cw * 0.47),
                               withAttributes: smallPipAttrs)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    let url = iconset.appendingPathComponent("icon_\(size).png")
    try! render(size).write(to: url)
    print("wrote \(url.lastPathComponent)")
}
print("✅ Solitaire icon set generated")
