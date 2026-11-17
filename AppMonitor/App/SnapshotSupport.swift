#if DEBUG
import AppKit

/// Developer-only utility used to verify the rendered UI in headless sessions.
/// Activate by launching the built binary with `APPMONITOR_SNAPSHOT_PATH` set
/// to an absolute PNG path. The app captures its own window (no screen recording
/// permission required), writes the image, and exits.
enum SnapshotSupport {
    static func installIfRequested() {
        guard let path = ProcessInfo.processInfo.environment["APPMONITOR_SNAPSHOT_PATH"],
              !path.isEmpty else { return }

        Task { @MainActor in
            // Live data needs another refresh or two before the CPU columns and
            // sparkline are meaningful. Screenshot passes can lengthen this.
            let delay = ProcessInfo.processInfo.environment["APPMONITOR_SNAPSHOT_DELAY"]
                .flatMap { Double($0) } ?? 2.4
            try? await Task.sleep(nanoseconds: UInt64(max(delay, 0) * 1_000_000_000))

            if let appearance = ProcessInfo.processInfo.environment["APPMONITOR_SNAPSHOT_APPEARANCE"] {
                NSApp.appearance = NSAppearance(named: appearance == "light" ? .aqua : .darkAqua)
            }

            NSApp.activate(ignoringOtherApps: true)
            try? await Task.sleep(nanoseconds: 1_100_000_000)

            guard let window = NSApp.windows.first(where: { $0.isVisible }) else {
                NSApp.terminate(nil)
                return
            }

            window.makeKeyAndOrderFront(nil)
            window.displayIfNeeded()

            if let data = capture(window: window) {
                try? data.write(to: URL(fileURLWithPath: path))
            }
            NSApp.terminate(nil)
        }
    }

    /// Captures the window as composited by the window server. Rendering the
    /// frame view with `cacheDisplay(in:to:)` can omit SwiftUI's layer-backed
    /// scroll content at compact widths, leaving the inspector black.
    ///
    /// `CGWindowListCreateImage` is deprecated in favor of ScreenCaptureKit,
    /// which requires Screen Recording permission. This DEBUG helper only
    /// captures the app's own window, so it needs no permission at all.
    private static func capture(window: NSWindow) -> Data? {
        let windowID = CGWindowID(window.windowNumber)
        guard let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else { return nil }

        return NSBitmapImageRep(cgImage: image)
            .representation(using: .png, properties: [:])
    }
}
#endif
