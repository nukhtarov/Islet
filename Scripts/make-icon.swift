// Draws the Islet app icon and writes Icon/AppIcon.icns.
// Usage: swift Scripts/make-icon.swift
import AppKit

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = size / 1024

    // macOS icon grid: 824pt rounded square centered in 1024.
    let body = CGRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let squircle = NSBezierPath(roundedRect: body, xRadius: 185 * s, yRadius: 185 * s)

    // Soft drop shadow.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 28 * s
    shadow.shadowOffset = NSSize(width: 0, height: -12 * s)
    shadow.set()
    NSColor.black.setFill()
    squircle.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Ocean gradient background.
    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()
    NSGradient(colors: [
        NSColor(red: 0.20, green: 0.85, blue: 0.95, alpha: 1),
        NSColor(red: 0.10, green: 0.45, blue: 0.95, alpha: 1),
        NSColor(red: 0.18, green: 0.12, blue: 0.55, alpha: 1),
    ], atLocations: [0, 0.55, 1], colorSpace: .deviceRGB)!.draw(in: body, angle: -90)

    // Subtle waves near the bottom.
    for (i, alpha) in [0.10, 0.07].enumerated() {
        let y = (250 - CGFloat(i) * 70) * s
        let wave = NSBezierPath()
        wave.move(to: CGPoint(x: body.minX, y: y))
        var x = body.minX
        while x < body.maxX {
            wave.curve(to: CGPoint(x: x + 206 * s, y: y),
                       controlPoint1: CGPoint(x: x + 70 * s, y: y + 34 * s),
                       controlPoint2: CGPoint(x: x + 136 * s, y: y - 34 * s))
            x += 206 * s
        }
        wave.lineWidth = 16 * s
        NSColor.white.withAlphaComponent(alpha).setStroke()
        wave.stroke()
    }

    // Top bezel strip with the notch "island" growing out of it.
    let island = CGRect(x: 232 * s, y: 470 * s, width: 560 * s, height: 340 * s)
    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = NSColor.black.withAlphaComponent(0.45)
    glow.shadowBlurRadius = 40 * s
    glow.shadowOffset = NSSize(width: 0, height: -16 * s)
    glow.set()
    NSColor.black.setFill()
    NSBezierPath(roundedRect: island, xRadius: 120 * s, yRadius: 120 * s).fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor.black.setFill()
    NSBezierPath(rect: CGRect(x: island.minX, y: island.midY, width: island.width, height: body.maxY - island.midY)).fill()
    // Flares where the island meets the top edge.
    for left in [true, false] {
        let r = 46 * s
        let edgeX = left ? island.minX : island.maxX
        let flare = NSBezierPath()
        flare.move(to: CGPoint(x: edgeX, y: body.maxY - r))
        flare.line(to: CGPoint(x: edgeX, y: body.maxY))
        flare.line(to: CGPoint(x: edgeX + (left ? -r : r), y: body.maxY))
        flare.curve(to: CGPoint(x: edgeX, y: body.maxY - r),
                    controlPoint1: CGPoint(x: edgeX + (left ? -r * 0.2 : r * 0.2), y: body.maxY),
                    controlPoint2: CGPoint(x: edgeX, y: body.maxY - r * 0.2))
        flare.fill()
    }

    // Camera dot.
    NSColor(white: 0.16, alpha: 1).setFill()
    NSBezierPath(ovalIn: CGRect(x: 494 * s, y: 852 * s, width: 36 * s, height: 36 * s)).fill()

    // Two lines of "text".
    NSColor.white.setFill()
    NSBezierPath(roundedRect: CGRect(x: 312 * s, y: 640 * s, width: 400 * s, height: 46 * s),
                 xRadius: 23 * s, yRadius: 23 * s).fill()
    NSColor.white.withAlphaComponent(0.55).setFill()
    NSBezierPath(roundedRect: CGRect(x: 372 * s, y: 556 * s, width: 280 * s, height: 46 * s),
                 xRadius: 23 * s, yRadius: 23 * s).fill()

    // Gloss.
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), NSColor.white.withAlphaComponent(0)])!
        .draw(in: CGRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("Icon/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        let data = drawIcon(size: CGFloat(px)).representation(using: .png, properties: [:])!
        try! data.write(to: iconset.appendingPathComponent(name))
    }
}
try! drawIcon(size: 1024).representation(using: .png, properties: [:])!
    .write(to: root.appendingPathComponent("Icon/AppIcon.png"))
print("Wrote \(iconset.path)")
