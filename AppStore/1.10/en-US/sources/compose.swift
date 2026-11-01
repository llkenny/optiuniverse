// Rebuild all 1.10 exports from the repository root:
// swift AppStore/1.10/en-US/sources/compose.swift
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


struct Export {
    let width: Int
    let height: Int
    let slide: Slide
    let capture: String
    let path: String
}

var exports: [Export] = []
for (width, height) in [(1320, 2868), (1206, 2622)] {
    for slide in slides {
        exports.append(Export(width: width, height: height, slide: slide,
                              capture: "sources/captures/iphone17/\(slide.slug).png",
                              path: "screenshots/\(width)x\(height)/\(slide.slug).png"))
    }
}
let duo: [(Int, Int, Int, String)] = [
    (1398, 2034, 0, "01-outer-portrait-saturn"),
    (1398, 2034, 5, "02-outer-portrait-crew13"),
    (2034, 1398, 3, "03-outer-landscape-earth"),
    (2034, 1398, 2, "04-outer-landscape-orbits"),
    (2007, 2853, 4, "05-inner-portrait-home"),
    (2007, 2853, 1, "06-inner-portrait-jupiter"),
    (2853, 2007, 1, "07-inner-landscape-jupiter"),
    (2853, 2007, 5, "08-inner-landscape-crew13")
]
for (width, height, index, slug) in duo {
    exports.append(Export(width: width, height: height, slide: slides[index],
                          capture: "sources/captures/duo/\(slug).png",
                          path: "screenshots/duo/\(width)x\(height)/\(slug).png"))
}

// Fit from the source pixel dimensions: no crop, stretch, or interface repainting.
func fittedPicture(_ path: String, in area: NSRect, accent: NSColor) {
    let image = NSImage(contentsOf: root.appendingPathComponent(path))!
    let source = image.representations[0]
    let ratio = CGFloat(source.pixelsWide) / CGFloat(source.pixelsHigh)
    let width = min(area.width, area.height * ratio)
    let height = width / ratio
    let frame = NSRect(x: area.midX - width / 2, y: area.midY - height / 2,
                       width: width, height: height)
    accent.withAlphaComponent(0.4).setStroke()
    let border = NSBezierPath(rect: frame.insetBy(dx: -2, dy: -2))
    border.lineWidth = 2
    border.stroke()
    picture(path, in: frame)
}

func headline(_ value: String, x: CGFloat, top: CGFloat, size: CGFloat,
              width: CGFloat, color: NSColor, height: CGFloat) {
    var fontSize = size
    while (value as NSString).size(withAttributes: [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold)
    ]).width > width { fontSize -= 1 }
    text(value, x: x, top: top, size: fontSize, color: color,
         weight: .bold, width: width, canvasHeight: height)
}

for item in exports {
    canvas(item.width, item.height, path: item.path) { width, height in
        background(width: width, height: height)
        let slide = item.slide
        if height > width {
            let left = width * 0.075
            text("OptiUniverse", x: left, top: height * 0.027, size: width * 0.025,
                 color: white, weight: .semibold, width: width * 0.85, canvasHeight: height)
            slide.accent.setFill()
            rect(left, height * 0.055, width * 0.056, 4, canvasHeight: height).fill()
            headline(slide.first, x: left, top: height * 0.076, size: min(width * 0.080, height * 0.037),
                     width: width * 0.85, color: white, height: height)
            headline(slide.second, x: left, top: height * 0.122, size: min(width * 0.080, height * 0.037),
                     width: width * 0.85, color: slide.accent, height: height)
            text(slide.subtitle, x: left, top: height * 0.184, size: min(width * 0.026, height * 0.016),
                 color: muted, width: width * 0.85, canvasHeight: height)
            fittedPicture(item.capture,
                          in: rect(width * 0.07, height * 0.235, width * 0.86, height * 0.735,
                                   canvasHeight: height), accent: slide.accent)
        } else {
            let left = width * 0.055
            let textWidth = width * 0.35
            text("OptiUniverse", x: left, top: height * 0.10, size: width * 0.020,
                 color: white, weight: .semibold, width: textWidth, canvasHeight: height)
            slide.accent.setFill()
            rect(left, height * 0.17, width * 0.045, 4, canvasHeight: height).fill()
            headline(slide.first, x: left, top: height * 0.25, size: width * 0.050,
                     width: textWidth, color: white, height: height)
            headline(slide.second, x: left, top: height * 0.39, size: width * 0.050,
                     width: textWidth, color: slide.accent, height: height)
            text(slide.subtitle, x: left, top: height * 0.57, size: width * 0.019,
                 color: muted, width: textWidth, canvasHeight: height)
            text("Explore on iPhone Duo", x: left, top: height * 0.81, size: width * 0.016,
                 color: muted, width: textWidth, canvasHeight: height)
            fittedPicture(item.capture,
                          in: rect(width * 0.445, height * 0.07, width * 0.515, height * 0.86,
                                   canvasHeight: height), accent: slide.accent)
        }
    }
}

// Copy the approved Header byte for byte, including when rebuilding a deleted export folder.
let previousHeader = root.deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("1.9/en-US/creative/header-3840x1646.png")
try! FileManager.default.createDirectory(at: root.appendingPathComponent("creative"),
                                         withIntermediateDirectories: true)
let headerData = try! Data(contentsOf: previousHeader)
try! headerData.write(to: root.appendingPathComponent("creative/header-3840x1646.png"))
canvas(3840, 2560, path: "creative/search-results-3840x2560.png") { width, height in
    picture("sources/artwork/search-generated.png",
            in: NSRect(x: 0, y: 0, width: width, height: height))
    text("OptiUniverse", x: 220, top: 160, size: 65, color: white,
         weight: .semibold, canvasHeight: height)
    text("Explore space", x: 208, top: 320, size: 190, color: white,
         weight: .bold, width: 2400, canvasHeight: height)
    text("in 3D", x: 208, top: 540, size: 190, color: blue,
         weight: .bold, canvasHeight: height)
    fittedPicture("sources/captures/iphone17/01-saturn.png",
                  in: rect(2670, 260, 930, 2040, canvasHeight: height), accent: blue)
}

canvas(2200, 2200, path: "preview.png") { width, height in
    background(width: width, height: height)
    text("OptiUniverse 1.10 / en-US", x: 40, top: 25, size: 36, color: white,
         weight: .semibold, canvasHeight: height)
    picture("creative/header-3840x1646.png",
            in: rect(40, 90, 1200, 1200 * 1646 / 3840, canvasHeight: height))
    picture("creative/search-results-3840x2560.png",
            in: rect(1290, 90, 860, 860 * 2 / 3, canvasHeight: height))
    text("iPhone / six scenes in two export sizes", x: 40, top: 690, size: 26,
         color: white, canvasHeight: height)
    for (index, slide) in slides.enumerated() {
        picture("screenshots/1320x2868/\(slide.slug).png",
                in: rect(40 + CGFloat(index) * 360, 750, 320, 320 * 2868 / 1320,
                         canvasHeight: height))
    }
    text("iPhone Duo / outer and inner displays / portrait and landscape", x: 40,
         top: 1490, size: 26, color: white, width: 2100, canvasHeight: height)
    for (index, item) in exports.suffix(8).enumerated() {
        let cell = rect(40 + CGFloat(index % 4) * 540, 1550 + CGFloat(index / 4) * 310,
                        500, 280, canvasHeight: height)
        fittedPicture(item.path, in: cell, accent: muted)
    }
}
