import Cocoa
import CoreGraphics

func renderIconRep(px: Int) -> NSBitmapImageRep? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px,
        pixelsHigh: px,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: px, height: px)

    NSGraphicsContext.saveGraphicsState()
    guard let gctx = NSGraphicsContext(bitmapImageRep: rep) else {
        NSGraphicsContext.restoreGraphicsState()
        return nil
    }
    NSGraphicsContext.current = gctx
    let ctx = gctx.cgContext

    let scale = CGFloat(px) / 1024.0
    ctx.saveGState()
    ctx.scaleBy(x: scale, y: scale)

    // 1. Outer Metallic Squircle Border
    let outerRect = CGRect(x: 84, y: 84, width: 856, height: 856)
    let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 192, yRadius: 192)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: NSColor(white: 0.0, alpha: 0.45).cgColor)
    NSColor(calibratedRed: 0.58, green: 0.63, blue: 0.68, alpha: 1.0).setFill()
    outerPath.fill()
    ctx.restoreGState()

    let borderGrad = NSGradient(colors: [
        NSColor(calibratedRed: 0.78, green: 0.82, blue: 0.86, alpha: 1.0),
        NSColor(calibratedRed: 0.25, green: 0.29, blue: 0.34, alpha: 1.0)
    ])!
    borderGrad.draw(in: outerPath, angle: -90)

    // 2. Inner Deep Space-Navy Squircle Background
    let innerRect = outerRect.insetBy(dx: 28, dy: 28)
    let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 168, yRadius: 168)
    let bgGrad = NSGradient(colors: [
        NSColor(calibratedRed: 0.22, green: 0.27, blue: 0.35, alpha: 1.0),
        NSColor(calibratedRed: 0.09, green: 0.12, blue: 0.18, alpha: 1.0)
    ])!
    bgGrad.draw(in: innerPath, angle: -90)

    // Cyan/Green inner rim glow
    NSColor(calibratedRed: 0.0, green: 0.88, blue: 0.75, alpha: 0.35).setStroke()
    innerPath.lineWidth = 4
    innerPath.stroke()

    // 3. Glowing Cyan Circuit Traces from Monitor to Keycaps
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 14, color: NSColor(calibratedRed: 0.0, green: 0.95, blue: 1.0, alpha: 0.85).cgColor)
    NSColor(calibratedRed: 0.15, green: 0.92, blue: 0.98, alpha: 0.95).setStroke()
    NSColor(calibratedRed: 0.15, green: 0.92, blue: 0.98, alpha: 0.95).setFill()

    let traces: [[(CGFloat, CGFloat)]] = [
        [(430, 480), (430, 410), (350, 360), (350, 310)],
        [(460, 480), (460, 390), (420, 345), (445, 295)],
        [(495, 480), (495, 375), (485, 315)],
        [(530, 480), (530, 395), (575, 355), (605, 320)],
        [(565, 480), (565, 415), (645, 375), (675, 330)],
        [(595, 480), (595, 435), (695, 405)]
    ]

    for pts in traces {
        let p = NSBezierPath()
        p.lineWidth = 7.5
        p.lineCapStyle = .round
        p.lineJoinStyle = .round
        p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
        for pt in pts.dropFirst() {
            p.line(to: CGPoint(x: pt.0, y: pt.1))
        }
        p.stroke()
        if let last = pts.last {
            let dot = NSBezierPath(ovalIn: CGRect(x: last.0 - 8, y: last.1 - 8, width: 16, height: 16))
            dot.fill()
        }
    }
    ctx.restoreGState()

    // 4. Center CRT / KVM Monitor Bezel & Screen
    let bezelRect = CGRect(x: 312, y: 472, width: 400, height: 300)
    let bezelPath = NSBezierPath(roundedRect: bezelRect, xRadius: 54, yRadius: 54)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor(calibratedRed: 0.0, green: 0.95, blue: 0.65, alpha: 0.45).cgColor)
    let bezelGrad = NSGradient(colors: [
        NSColor(calibratedRed: 0.52, green: 0.58, blue: 0.65, alpha: 1.0),
        NSColor(calibratedRed: 0.22, green: 0.27, blue: 0.33, alpha: 1.0)
    ])!
    bezelGrad.draw(in: bezelPath, angle: -90)
    ctx.restoreGState()

    let screenRect = bezelRect.insetBy(dx: 28, dy: 28)
    let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: 34, yRadius: 34)
    let screenGrad = NSGradient(colors: [
        NSColor(calibratedRed: 0.07, green: 0.22, blue: 0.20, alpha: 1.0),
        NSColor(calibratedRed: 0.02, green: 0.07, blue: 0.09, alpha: 1.0)
    ])!
    screenGrad.draw(in: screenPath, angle: -75)

    // Terminal scanlines & prompt bars inside screen
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 8, color: NSColor(calibratedRed: 0.1, green: 1.0, blue: 0.55, alpha: 0.8).cgColor)
    NSColor(calibratedRed: 0.22, green: 0.98, blue: 0.58, alpha: 0.95).setFill()

    let codeBars: [(CGFloat, CGFloat, CGFloat)] = [
        (372, 682, 34),
        (372, 654, 42), (424, 654, 92),
        (372, 634, 42), (424, 634, 130),
        (372, 614, 42), (424, 614, 165),
        (372, 594, 42), (424, 594, 78),
        (386, 558, 32), (430, 558, 86),
        (386, 538, 32), (430, 538, 125),
        (372, 508, 34)
    ]
    for (bx, by, bw) in codeBars {
        let bar = NSBezierPath(roundedRect: CGRect(x: bx, y: by, width: bw, height: 10), xRadius: 4, yRadius: 4)
        bar.fill()
    }
    ctx.restoreGState()

    // 5. Two 3D Mechanical Keycaps in Foreground
    func drawKeycap(centerX: CGFloat, centerY: CGFloat, glowColor: NSColor) {
        ctx.saveGState()
        ctx.translateBy(x: centerX, y: centerY)
        ctx.rotate(by: 0.22)

        let baseRect = CGRect(x: -88, y: -74, width: 176, height: 148)
        let basePath = NSBezierPath(roundedRect: baseRect, xRadius: 26, yRadius: 26)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: glowColor.cgColor)
        NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.22, alpha: 1.0).setFill()
        basePath.fill()
        glowColor.setStroke()
        basePath.lineWidth = 6
        basePath.stroke()
        ctx.restoreGState()

        let capBody = CGRect(x: -76, y: -56, width: 152, height: 136)
        let capBodyPath = NSBezierPath(roundedRect: capBody, xRadius: 24, yRadius: 24)
        let bodyGrad = NSGradient(colors: [
            NSColor(calibratedRed: 0.44, green: 0.49, blue: 0.55, alpha: 1.0),
            NSColor(calibratedRed: 0.18, green: 0.22, blue: 0.27, alpha: 1.0)
        ])!
        bodyGrad.draw(in: capBodyPath, angle: -90)

        let capTop = CGRect(x: -60, y: -26, width: 120, height: 96)
        let capTopPath = NSBezierPath(roundedRect: capTop, xRadius: 18, yRadius: 18)
        let topGrad = NSGradient(colors: [
            NSColor(calibratedRed: 0.68, green: 0.73, blue: 0.78, alpha: 1.0),
            NSColor(calibratedRed: 0.48, green: 0.53, blue: 0.59, alpha: 1.0)
        ])!
        topGrad.draw(in: capTopPath, angle: -90)

        ctx.restoreGState()
    }

    drawKeycap(centerX: 515, centerY: 255, glowColor: NSColor(calibratedRed: 0.0, green: 0.90, blue: 1.0, alpha: 0.95))
    drawKeycap(centerX: 685, centerY: 295, glowColor: NSColor(calibratedRed: 0.1, green: 1.0, blue: 0.55, alpha: 0.95))

    ctx.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func appendUInt32BE(_ data: inout Data, _ val: UInt32) {
    var be = val.bigEndian
    data.append(Data(bytes: &be, count: 4))
}

// Build binary Apple .icns container directly with embedded PNG chunks
let icnsChunks: [(String, Int)] = [
    ("icp4", 16),
    ("icp5", 32),
    ("icp6", 64),
    ("ic07", 128),
    ("ic08", 256),
    ("ic09", 512),
    ("ic10", 1024)
]

var bodyData = Data()
for (tag, px) in icnsChunks {
    guard let rep = renderIconRep(px: px),
          let png = rep.representation(using: .png, properties: [:]) else {
        continue
    }
    bodyData.append(tag.data(using: .ascii)!)
    appendUInt32BE(&bodyData, UInt32(8 + png.count))
    bodyData.append(png)
}

var icnsData = Data()
icnsData.append("icns".data(using: .ascii)!)
appendUInt32BE(&icnsData, UInt32(8 + bodyData.count))
icnsData.append(bodyData)

let icnsURL = URL(fileURLWithPath: "/Users/neo/projects/tmp/MiniKVM.app/Contents/Resources/AppIcon.icns")
try icnsData.write(to: icnsURL)

if let rep1024 = renderIconRep(px: 1024),
   let png1024 = rep1024.representation(using: .png, properties: [:]) {
    try png1024.write(to: URL(fileURLWithPath: "/Users/neo/projects/tmp/AppIcon.png"))
    try png1024.write(to: URL(fileURLWithPath: "/Users/neo/projects/tmp/MiniKVM.app/Contents/Resources/AppIcon.png"))
    if let nsImg = NSImage(data: png1024) {
        _ = NSWorkspace.shared.setIcon(nsImg, forFile: "/Users/neo/projects/tmp/MiniKVM.app", options: [])
    }
}
print("Wrote valid ICNS (\(icnsData.count) bytes) and applied bundle icon.")
