// Renders the app icon (SF Symbol "scope" on a blue gradient, same symbol as the menu bar)
// and writes it as .icns directly (no iconutil needed).
// Usage: swiftc make-icon.swift -o make-icon && ./make-icon <out.icns>
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns"

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let full = NSRect(x: 0, y: 0, width: px, height: px)
    // macOS icons leave a transparent margin around the rounded square
    let r = full.insetBy(dx: full.width * 0.09, dy: full.height * 0.09)
    let bg = NSBezierPath(roundedRect: r, xRadius: r.width * 0.225, yRadius: r.width * 0.225)
    NSGradient(
        starting: NSColor(calibratedRed: 0.30, green: 0.62, blue: 1.00, alpha: 1),
        ending: NSColor(calibratedRed: 0.08, green: 0.30, blue: 0.80, alpha: 1)
    )!.draw(in: bg, angle: -90)

    let cfg = NSImage.SymbolConfiguration(pointSize: r.width * 0.56, weight: .medium)
        .applying(.init(paletteColors: [.white]))
    if let sym = NSImage(systemSymbolName: "scope", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
        let s = sym.size
        let dst = NSRect(x: r.midX - s.width / 2, y: r.midY - s.height / 2, width: s.width, height: s.height)
        sym.draw(in: dst, from: .zero, operation: .sourceOver, fraction: 1)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// ICNS element types that accept PNG payloads, with their pixel sizes
let elements: [(type: String, px: Int)] = [
    ("icp4", 16), ("icp5", 32), ("icp6", 64), ("ic07", 128), ("ic08", 256), ("ic09", 512), ("ic10", 1024),
    ("ic11", 32), ("ic12", 64), ("ic13", 256), ("ic14", 512),
]

func be32(_ v: Int) -> Data {
    var n = UInt32(v).bigEndian
    return Data(bytes: &n, count: 4)
}

var body = Data()
for e in elements {
    let png = render(e.px)
    body.append(e.type.data(using: .ascii)!)
    body.append(be32(png.count + 8))
    body.append(png)
}
var icns = Data("icns".utf8)
icns.append(be32(body.count + 8))
icns.append(body)
try! icns.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath) (\(icns.count) bytes, \(elements.count) sizes)")
