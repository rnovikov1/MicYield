import AppKit

// Original MicYield artwork. Rendered locally; no downloaded art or runtime dependencies.
let destination = CommandLine.arguments.dropFirst().first ?? "build/MicYield.iconset"
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
func render(_ pixels: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.scaleBy(x: Double(pixels) / 1024, y: Double(pixels) / 1024)
    context.setAllowsAntialiasing(true)
    let tile = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 194, yRadius: 194)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -15)
    shadow.set()
    NSColor(srgbRed: 0.77, green: 0.24, blue: 0.19, alpha: 1).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    let top = NSColor(srgbRed: 0.94, green: 0.43, blue: 0.37, alpha: 1)
    let bottom = NSColor(srgbRed: 0.77, green: 0.24, blue: 0.19, alpha: 1)
    NSGradient(starting: bottom, ending: top)!.draw(in: tile, angle: 90)
    NSColor(srgbRed: 1, green: 0.98, blue: 0.95, alpha: 1).setFill()
    for (index, height) in [120.0, 280.0, 464.0, 280.0, 120.0].enumerated() {
        let x = 264.0 + Double(index) * 110.0
        NSBezierPath(roundedRect: NSRect(x: x, y: 512 - height / 2, width: 56, height: height), xRadius: 28, yRadius: 28).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        let png = try render(points * scale)
        try png.write(to: URL(fileURLWithPath: destination).appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
print("Generated MicYield icon at 16–1024 pixels: \(destination)")
