#!/usr/bin/env swift
import AppKit
import Foundation

let outputDirectory = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppMonitor/Resources/Assets.xcassets/AppIcon.appiconset"

func makeIcon(pixelSize: Int) -> NSImage {
    let size = CGFloat(pixelSize)
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()
    guard let context = NSGraphicsContext.current else {
        image.unlockFocus()
        return image
    }
    context.imageInterpolation = .high

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let inset = size * 0.055
    let iconRect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let corner = size * 0.225
    let shape = NSBezierPath(roundedRect: iconRect, xRadius: corner, yRadius: corner)

    // Soft floating shadow beneath the tile.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = size * 0.045
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.018)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.32)
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Calm navy-to-teal base, matching the app's inspector accents.
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.025, green: 0.105, blue: 0.190, alpha: 1),
        NSColor(srgbRed: 0.025, green: 0.255, blue: 0.315, alpha: 1),
        NSColor(srgbRed: 0.035, green: 0.415, blue: 0.430, alpha: 1)
    ])
    gradient?.draw(in: shape, angle: -62)

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()

    // A single quiet glow keeps the mark readable at small sizes.
    let glow = NSGradient(colors: [
        NSColor(srgbRed: 0.23, green: 0.92, blue: 0.85, alpha: 0.22),
        NSColor(srgbRed: 0.23, green: 0.92, blue: 0.85, alpha: 0.0)
    ])
    glow?.draw(
        fromCenter: NSPoint(x: iconRect.midX, y: iconRect.midY),
        radius: 0,
        toCenter: NSPoint(x: iconRect.midX, y: iconRect.midY),
        radius: iconRect.width * 0.52,
        options: []
    )
    NSGraphicsContext.restoreGraphicsState()

    // Inner rim.
    let rim = NSBezierPath(
        roundedRect: iconRect.insetBy(dx: size * 0.006, dy: size * 0.006),
        xRadius: corner,
        yRadius: corner
    )
    rim.lineWidth = size * 0.007
    NSColor.white.withAlphaComponent(0.20).setStroke()
    rim.stroke()

    // Simple power mark: an open ring with a single vertical stem.
    let center = NSPoint(x: iconRect.midX, y: iconRect.midY)
    let radius = iconRect.width * 0.245
    let lineWidth = iconRect.width * 0.078

    let ring = NSBezierPath()
    ring.appendArc(
        withCenter: center,
        radius: radius,
        startAngle: 120,
        endAngle: 420,
        clockwise: false
    )
    ring.lineWidth = lineWidth
    ring.lineCapStyle = .round
    ring.lineJoinStyle = .round

    let stem = NSBezierPath()
    stem.move(to: NSPoint(x: center.x, y: center.y + lineWidth * 0.12))
    stem.line(to: NSPoint(x: center.x, y: center.y + radius + lineWidth * 0.28))
    stem.lineWidth = lineWidth
    stem.lineCapStyle = .round

    NSGraphicsContext.saveGraphicsState()
    let glowShadow = NSShadow()
    glowShadow.shadowBlurRadius = size * 0.042
    glowShadow.shadowOffset = .zero
    glowShadow.shadowColor = NSColor(srgbRed: 0.34, green: 0.96, blue: 0.90, alpha: 0.72)
    glowShadow.set()
    NSColor(srgbRed: 0.955, green: 1.0, blue: 0.995, alpha: 1).setStroke()
    ring.stroke()
    stem.stroke()
    NSGraphicsContext.restoreGraphicsState()

    image.unlockFocus()
    return image
}

func pngData(for image: NSImage, pixelSize: Int) -> Data? {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
    bitmap.size = NSSize(width: pixelSize, height: pixelSize)
    return bitmap.representation(using: .png, properties: [:])
}

try FileManager.default.createDirectory(
    atPath: outputDirectory,
    withIntermediateDirectories: true
)

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, size) in variants {
    let image = makeIcon(pixelSize: size)
    guard let data = pngData(for: image, pixelSize: size) else {
        fatalError("Could not render \(filename)")
    }
    try data.write(to: URL(fileURLWithPath: outputDirectory).appendingPathComponent(filename))
}

let contents = """
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try contents.write(
    to: URL(fileURLWithPath: outputDirectory).appendingPathComponent("Contents.json"),
    atomically: true,
    encoding: .utf8
)

if outputDirectory.hasSuffix("AppIcon.appiconset") {
    // Xcode's asset catalog handles the modern icon, but Finder also reads the
    // standalone .icns referenced by CFBundleIconFile. Keep both in sync.
    let iconsetURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AppMonitor-\(UUID().uuidString).iconset")
    try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: iconsetURL) }

    for (filename, _) in variants {
        try FileManager.default.copyItem(
            at: URL(fileURLWithPath: outputDirectory).appendingPathComponent(filename),
            to: iconsetURL.appendingPathComponent(filename)
        )
    }

    let resourcesURL = URL(fileURLWithPath: outputDirectory)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")

    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
    try iconutil.run()
    iconutil.waitUntilExit()

    guard iconutil.terminationStatus == 0 else {
        fatalError("iconutil failed with status \(iconutil.terminationStatus)")
    }
    print("Generated \(icnsURL.path)")
}

print("Generated app icon set at \(outputDirectory)")
