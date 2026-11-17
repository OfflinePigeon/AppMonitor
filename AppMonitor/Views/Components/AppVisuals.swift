import AppKit
import SwiftUI

/// Loads real application icons when the bundle is installed, with a polished
/// gradient-and-SF-Symbol fallback so previews and offline data always look
/// intentional. Results are cached because list rows redraw frequently.
@MainActor
enum AppIconLoader {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(for process: MonitoredProcess) -> NSImage? {
        let key = (process.bundleIdentifier ?? process.appBundlePath ?? process.name) as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        var image: NSImage?
        if let bundleIdentifier = process.bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            image = NSWorkspace.shared.icon(forFile: url.path)
        } else if let appBundlePath = process.appBundlePath,
                  FileManager.default.fileExists(atPath: appBundlePath) {
            image = NSWorkspace.shared.icon(forFile: appBundlePath)
        } else if let executablePath = process.executablePath,
                  let bundle = outermostAppBundle(for: executablePath) {
            image = NSWorkspace.shared.icon(forFile: bundle)
        }

        if let image {
            cache.setObject(image, forKey: key)
        }
        return image
    }

    private static func outermostAppBundle(for path: String) -> String? {
        var url = URL(fileURLWithPath: path)
        var found: String?
        while url.path != "/" {
            if url.pathExtension == "app" {
                found = url.path
            }
            url.deleteLastPathComponent()
        }
        return found
    }
}

/// Sharp, correctly scaled version of a macOS app icon.
struct AppIconView: View {
    let process: MonitoredProcess
    var size: CGFloat = 30

    var body: some View {
        Group {
            if let icon = AppIconLoader.icon(for: process) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.235, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 1.5, x: 0, y: 1)
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        let seed = abs((process.bundleIdentifier ?? process.name).hashValue)
        let palettes: [[Color]] = [
            [.blue, .cyan],
            [.indigo, .purple],
            [.teal, .green],
            [.orange, .pink],
            [.purple, .blue],
            [.green, .mint]
        ]
        let colors = palettes[seed % palettes.count]
        return ZStack {
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: symbolName)
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var symbolName: String {
        let name = process.displayTitle.lowercased()
        if name.contains("safari") { return "safari.fill" }
        if name.contains("mail") { return "envelope.fill" }
        if name.contains("music") { return "music.note" }
        if name.contains("calendar") { return "calendar" }
        if name.contains("terminal") { return "terminal.fill" }
        if name.contains("code") || name.contains("xcode") { return "chevron.left.forwardslash.chevron.right" }
        if name.contains("chrome") { return "globe" }
        if name.contains("teams") || name.contains("message") { return "bubble.left.and.bubble.right.fill" }
        if name.contains("zoom") { return "video.fill" }
        if name.contains("claude") { return "sparkles" }
        return process.kind.symbolName
    }
}

/// AppMonitor's brand mark, reused in the sidebar and empty states.
struct AppMarkView: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.16, green: 0.48, blue: 0.95),
                                 Color(red: 0.10, green: 0.72, blue: 0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: size * 0.52, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.blue.opacity(0.25), radius: size * 0.12, x: 0, y: size * 0.06)
        .accessibilityHidden(true)
    }
}

/// Small pasteboard convenience shared by row context menus and detail actions.
enum Clipboard {
    static func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

/// A tiny kind badge used by child rows.
struct ProcessKindIcon: View {
    let kind: ProcessKind
    var size: CGFloat = 16

    var body: some View {
        Image(systemName: kind.symbolName)
            .font(.system(size: size * 0.66, weight: .semibold))
            .foregroundStyle(MetricPalette.tint(for: kind))
            .frame(width: size, height: size)
            .accessibilityLabel(kind.title)
    }
}

/// Capsule-style status indicator used in the detail panel.
struct StatusPill: View {
    let title: String
    var color: Color = .green
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 8, weight: .bold))
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            }
            Text(title)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.12)))
    }
}
