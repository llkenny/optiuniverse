// Rebuild release layouts from saved app captures. Run from this file's directory:
// swift compose.swift
import AppKit
import ImageIO

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let white = NSColor(srgbRed: 0.96, green: 0.97, blue: 1, alpha: 1)
let muted = NSColor(srgbRed: 0.63, green: 0.69, blue: 0.77, alpha: 1)
let blue = NSColor(srgbRed: 0.30, green: 0.74, blue: 0.96, alpha: 1)
let gold = NSColor(srgbRed: 0.91, green: 0.75, blue: 0.46, alpha: 1)
let dark = NSColor(srgbRed: 0.018, green: 0.027, blue: 0.046, alpha: 1)

struct Slide {
    let slug: String
    let first: String
    let second: String
    let subtitle: String
    let accent: NSColor
}

let slides = [
    Slide(slug: "01-saturn", first: "Explore the", second: "Solar System",
          subtitle: "Get closer to extraordinary worlds.", accent: gold),
    Slide(slug: "02-jupiter", first: "Discover", second: "Giant Planets",
          subtitle: "Explore in 3D. Discover the details.", accent: gold),
    Slide(slug: "03-orbits", first: "Visualize", second: "Planetary Orbits",
          subtitle: "See our Solar System in motion.", accent: blue),
    Slide(slug: "04-earth", first: "Explore Earth", second: "in Detail",
          subtitle: "Find a new perspective on home.", accent: blue),
    Slide(slug: "05-home", first: "Choose Your", second: "Next Mission",
          subtitle: "Space journeys start here.", accent: gold),
    Slide(slug: "06-crew13", first: "Replay", second: "Space Missions",
          subtitle: "Follow an illustrative flight to the ISS.", accent: blue)
]

func canvas(_ width: Int, _ height: Int, path: String,
            drawing: (CGFloat, CGFloat) -> Void) {
    let context = CGContext(data: nil, width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let graphics = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    drawing(CGFloat(width), CGFloat(height))
    NSGraphicsContext.restoreGraphicsState()
    let destination = root.appendingPathComponent(path)
    try! FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    let output = CGImageDestinationCreateWithURL(destination as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(output, context.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(output), "Could not export \(path)")
    print(path)
}

func rect(_ x: CGFloat, _ top: CGFloat, _ width: CGFloat, _ height: CGFloat,
          canvasHeight: CGFloat) -> NSRect {
    NSRect(x: x, y: canvasHeight - top - height, width: width, height: height)
}

func text(_ value: String, x: CGFloat, top: CGFloat, size: CGFloat,
          color: NSColor, weight: NSFont.Weight = .regular,
          width: CGFloat = 1200, canvasHeight: CGFloat) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color, .paragraphStyle: paragraph,
        .kern: weight == .bold ? -size * 0.025 : 0
    ]
    NSAttributedString(string: value, attributes: attributes).draw(
        in: rect(x, top, width, size * 2.6, canvasHeight: canvasHeight))
}

func background(width: CGFloat, height: CGFloat) {
    dark.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    // Sparse deterministic points remain outside the unmodified app capture.
    for index in 0..<110 {
        let x = CGFloat((index * 397 + 83) % Int(width))
        let y = CGFloat((index * 719 + 31) % Int(height))
        NSColor(white: 0.7, alpha: index % 7 == 0 ? 0.30 : 0.11).setFill()
        NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 1.8, height: 1.8)).fill()
    }
}

func picture(_ relativePath: String, in frame: NSRect, radius: CGFloat = 0) {
    NSGraphicsContext.saveGraphicsState()
    if radius > 0 { NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius).addClip() }
    let image = NSImage(contentsOf: root.appendingPathComponent(relativePath))!
    image.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

canvas(3840, 1646, path: "creative/header-3840x1646.png") { width, height in
    picture("sources/artwork/header-generated.png",
            in: NSRect(x: 0, y: 0, width: width, height: height))
}

for (width, height) in [(1320, 2868), (1206, 2622)] {
    for slide in slides {
        canvas(width, height, path: "screenshots/\(width)x\(height)/\(slide.slug).png") { pixelWidth, pixelHeight in
            let scale = pixelWidth / 1320
            let height = pixelHeight / scale
            NSGraphicsContext.current!.cgContext.scaleBy(x: scale, y: scale)
            background(width: 1320, height: height)
            text("OptiUniverse", x: 100, top: 92, size: 32, color: white,
                 weight: .semibold, canvasHeight: height)
            slide.accent.setFill()
            rect(100, 157, 74, 4, canvasHeight: height).fill()
            text(slide.first, x: 94, top: 211, size: 106, color: white,
                 weight: .bold, canvasHeight: height)
            text(slide.second, x: 94, top: 328, size: 106, color: slide.accent,
                 weight: .bold, canvasHeight: height)
            text(slide.subtitle, x: 100, top: 480, size: 36, color: muted, canvasHeight: height)
            let frame = rect(168, 620, 984, 984 * 2622 / 1206, canvasHeight: height)
            let border = NSBezierPath(roundedRect: frame.insetBy(dx: -3, dy: -3),
                                      xRadius: 59, yRadius: 59)
            slide.accent.withAlphaComponent(0.37).setStroke()
            border.lineWidth = 2
            border.stroke()
            picture("sources/captures/\(slide.slug).png", in: frame, radius: 56)
        }
    }
}

canvas(3840, 2560, path: "creative/search-results-3840x2560.png") { width, height in
    // Full-bleed advertising art surrounds a genuine, unmodified app screen.
    picture("sources/artwork/search-generated.png",
            in: NSRect(x: 0, y: 0, width: width, height: height))
    text("OptiUniverse", x: 220, top: 160, size: 65, color: white,
         weight: .semibold, canvasHeight: height)
    text("Explore space", x: 208, top: 320, size: 190, color: white,
         weight: .bold, width: 2400, canvasHeight: height)
    text("in 3D", x: 208, top: 540, size: 190, color: blue,
         weight: .bold, canvasHeight: height)
    let frame = rect(2670, 260, 930, 930 * 2622 / 1206, canvasHeight: height)
    let border = NSBezierPath(roundedRect: frame.insetBy(dx: -4, dy: -4),
                              xRadius: 58, yRadius: 58)
    blue.withAlphaComponent(0.50).setStroke()
    border.lineWidth = 3
    border.stroke()
    picture("sources/captures/01-saturn.png", in: frame, radius: 54)
}

canvas(1800, 1390, path: "preview.png") { width, height in
    background(width: width, height: height)
    text("OptiUniverse 1.9 / en-US", x: 40, top: 25, size: 30, color: white,
         weight: .semibold, canvasHeight: height)
    picture("creative/header-3840x1646.png",
            in: rect(40, 90, 1000, 1000 * 1646 / 3840, canvasHeight: height))
    picture("creative/search-results-3840x2560.png",
            in: rect(1080, 90, 680, 680 * 2 / 3, canvasHeight: height))
    for (index, slide) in slides.enumerated() {
        picture("screenshots/1320x2868/\(slide.slug).png",
                in: rect(40 + CGFloat(index) * 288, 600, 270, 270 * 2868 / 1320,
                         canvasHeight: height))
    }
}
