#!/usr/bin/env swift
import AppKit
import Foundation

let outputDirectory = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppMonitor/Resources/Assets.xcassets/AppIcon.appiconset"

func point(in rect: NSRect, _ x: CGFloat, _ y: CGFloat) -> NSPoint {
    NSPoint(
        x: rect.minX + rect.width * x,
        y: rect.minY + rect.height * y
    )
}

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
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.025, green: 0.095, blue: 0.190, alpha: 1),
        NSColor(srgbRed: 0.035, green: 0.275, blue: 0.470, alpha: 1),
        NSColor(srgbRed: 0.045, green: 0.585, blue: 0.585, alpha: 1)
    ])
    gradient?.draw(in: shape, angle: -55)

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()

    // Cyan glow behind the screen.
    let glow = NSGradient(colors: [
        NSColor(srgbRed: 0.15, green: 0.90, blue: 0.88, alpha: 0.34),
        NSColor(srgbRed: 0.15, green: 0.90, blue: 0.88, alpha: 0.0)
    ])
    glow?.draw(
        fromCenter: point(in: iconRect, 0.58, 0.57),
        radius: 0,
        toCenter: point(in: iconRect, 0.58, 0.57),
        radius: iconRect.width * 0.52,
        options: []
    )

    // Glassy top-left sheen.
    let sheen = NSBezierPath(ovalIn: NSRect(
        x: iconRect.minX - size * 0.28,
        y: iconRect.minY + size * 0.40,
        width: size * 1.15,
        height: size * 0.90
    ))
    NSColor.white.withAlphaComponent(0.10).setFill()
    sheen.fill()

    // Subtle bottom shade.
    let shadeRect = NSRect(x: iconRect.minX, y: iconRect.minY, width: iconRect.width, height: iconRect.height * 0.45)
    let shade = NSGradient(colors: [
        NSColor.black.withAlphaComponent(0.0),
        NSColor.black.withAlphaComponent(0.24)
    ])
    shade?.draw(in: shadeRect, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Inner rim.
    let rim = NSBezierPath(
        roundedRect: iconRect.insetBy(dx: size * 0.006, dy: size * 0.006),
        xRadius: corner,
        yRadius: corner
    )
    rim.lineWidth = size * 0.007
    NSColor.white.withAlphaComponent(0.24).setStroke()
    rim.stroke()

    // Monitor screen.
    let screen = NSRect(
        x: iconRect.minX + iconRect.width * 0.17,
        y: iconRect.minY + iconRect.height * 0.335,
        width: iconRect.width * 0.66,
        height: iconRect.height * 0.365
    )
    let screenCorner = size * 0.060
    let screenPath = NSBezierPath(roundedRect: screen, xRadius: screenCorner, yRadius: screenCorner)
    NSColor.white.withAlphaComponent(0.055).setFill()
    screenPath.fill()
    screenPath.lineWidth = size * 0.034
    screenPath.lineJoinStyle = .round
    NSColor.white.withAlphaComponent(0.94).setStroke()
    screenPath.stroke()

    // Monitor stand.
    let neck = NSBezierPath()
    neck.move(to: NSPoint(x: iconRect.midX - size * 0.032, y: screen.minY))
    neck.line(to: NSPoint(x: iconRect.midX - size * 0.032, y: iconRect.minY + iconRect.height * 0.265))
    neck.line(to: NSPoint(x: iconRect.midX + size * 0.032, y: iconRect.minY + iconRect.height * 0.265))
    neck.line(to: NSPoint(x: iconRect.midX + size * 0.032, y: screen.minY))
    neck.lineWidth = size * 0.026
    neck.lineCapStyle = .round
    neck.lineJoinStyle = .round
    NSColor.white.withAlphaComponent(0.94).setStroke()
    neck.stroke()

    let base = NSBezierPath(
        roundedRect: NSRect(
            x: iconRect.midX - size * 0.105,
            y: iconRect.minY + iconRect.height * 0.205,
            width: size * 0.210,
            height: size * 0.030
        ),
        xRadius: size * 0.015,
        yRadius: size * 0.015
    )
    NSColor.white.withAlphaComponent(0.94).setFill()
    base.fill()

    // Live indicator.
    let liveRadius = size * 0.027
    let liveCenter = NSPoint(
        x: screen.maxX - size * 0.075,
        y: screen.maxY - size * 0.060
    )
    let liveGlow = NSGradient(colors: [
        NSColor(srgbRed: 0.35, green: 1.0, blue: 0.60, alpha: 0.55),
        NSColor(srgbRed: 0.35, green: 1.0, blue: 0.60, alpha: 0.0)
    ])
    liveGlow?.draw(
        fromCenter: liveCenter,
        radius: 0,
        toCenter: liveCenter,
        radius: liveRadius * 3.2,
        options: []
    )
    NSColor(srgbRed: 0.47, green: 1.0, blue: 0.68, alpha: 1).setFill()
    NSBezierPath(
        ovalIn: NSRect(
            x: liveCenter.x - liveRadius,
            y: liveCenter.y - liveRadius,
            width: liveRadius * 2,
            height: liveRadius * 2
        )
    ).fill()

    // Pulse line inside the screen.
    let pulse = NSBezierPath()
    pulse.move(to: point(in: screen, 0.10, 0.47))
    pulse.line(to: point(in: screen, 0.31, 0.47))
    pulse.line(to: point(in: screen, 0.40, 0.67))
    pulse.line(to: point(in: screen, 0.51, 0.27))
    pulse.line(to: point(in: screen, 0.61, 0.59))
    pulse.line(to: point(in: screen, 0.70, 0.47))
    pulse.line(to: point(in: screen, 0.90, 0.47))
    pulse.lineWidth = size * 0.046
    pulse.lineCapStyle = .round
    pulse.lineJoinStyle = .round

    NSGraphicsContext.saveGraphicsState()
    let pulseGlow = NSShadow()
    pulseGlow.shadowBlurRadius = size * 0.030
    pulseGlow.shadowOffset = .zero
    pulseGlow.shadowColor = NSColor(srgbRed: 0.25, green: 0.95, blue: 0.92, alpha: 0.85)
    pulseGlow.set()
    NSColor.white.setStroke()
    pulse.stroke()
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
