import AppKit

// Build the installer artwork locally at 1x and 2x, without external fonts/assets.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}
func render(scale: Int, name: String) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 640 * scale,
        pixelsHigh: 360 * scale, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = NSSize(width: 640, height: 360)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    // The bitmap logical size already gives this context its Retina transform.
    color(0xfcfbf9).setFill()
    NSRect(x: 0, y: 0, width: 640, height: 360).fill()
    func text(_ value: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight, ink: UInt32) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        (value as NSString).draw(in: NSRect(x: 32, y: y, width: 576, height: 38),
            withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight),
                             .foregroundColor: color(ink), .paragraphStyle: style])
    }
    text("Make room for your voice.", y: 286, size: 25, weight: .semibold, ink: 0x222326)
    text("Drag MicYield to Applications", y: 256, size: 14, weight: .regular, ink: 0x656365)
    color(0xc43d30).setStroke()
    let arrow = NSBezierPath()
    arrow.lineWidth = 2.5
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.move(to: NSPoint(x: 281, y: 188))
    arrow.line(to: NSPoint(x: 355, y: 188))
    arrow.move(to: NSPoint(x: 344, y: 199))
    arrow.line(to: NSPoint(x: 355, y: 188))
    arrow.line(to: NSPoint(x: 344, y: 177))
    arrow.stroke()
    text("Then open MicYield from Applications.", y: 61, size: 13, weight: .regular, ink: 0x656365)
    text("macOS 14.2+   ·   Apple Silicon & Intel", y: 29, size: 11, weight: .medium, ink: 0x858181)
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
try render(scale: 1, name: "background.png")
try render(scale: 2, name: "background@2x.png")
