import AppKit

// Draws the app icon (a rounded square with a terminal prompt) into an .iconset folder.
// Usage: icon OUT.iconset      (make-icon.sh turns the result into an .icns)

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let inset = s * 0.08
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: rect, xRadius: s * 0.22, yRadius: s * 0.22)
    let top = NSColor(calibratedRed: 0.96, green: 0.55, blue: 0.30, alpha: 1)
    let bottom = NSColor(calibratedRed: 0.85, green: 0.38, blue: 0.18, alpha: 1)
    NSGradient(starting: top, ending: bottom)?.draw(in: path, angle: -90)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: s * 0.42, weight: .bold),
        .foregroundColor: NSColor.white
    ]
    let text = NSAttributedString(string: ">_", attributes: attrs)
    let size = text.size()
    text.draw(at: NSPoint(x: (s - size.width) / 2, y: (s - size.height) / 2))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let sizes: [(String, Int)] = [
    ("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64),
    ("128x128", 128), ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512),
    ("512x512", 512), ("512x512@2x", 1024)
]
for (name, px) in sizes {
    if let data = render(px) {
        try? data.write(to: URL(fileURLWithPath: out + "/icon_\(name).png"))
    }
}
