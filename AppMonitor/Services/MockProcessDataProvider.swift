import Foundation

/// A deterministic, realistic workload used exclusively by unit tests and
/// SwiftUI previews. The shipping app always samples the live system.
///
/// The data mirrors the shape of a real process table: app roots own helper
/// renderers, some helpers own nested workers, and a handful of standalone
/// agents are present specifically so the filtering can be verified visually
/// and in tests. Memory figures use physical-footprint-style values.
enum MockScenario {
    static let hostMemoryBytes: UInt64 = 32 * 1_073_741_824
    static let logicalCoreCount = 10

    /// Processes that exist system-wide but are not part of the mock process
    /// table at all. They make the sidebar's filtered count feel honest.
    static let additionalHiddenBackgroundCount = 27

    struct Seed {
        let pid: Int32
        let parentPID: Int32
        let name: String
        var displayName: String? = nil
        var path: String
        var appBundlePath: String? = nil
        var bundleIdentifier: String? = nil
        var isApplicationRoot = false
        var kind: ProcessKind = .helper
        var cpu: Double
        var memoryMB: Double
        var threads: Int
        var startedMinutesAgo: Double
    }

    // MARK: - Application roots

    private static let chromeBundle = "/Applications/Google Chrome.app"
    private static let chromePath = chromeBundle + "/Contents/MacOS/Google Chrome"
    private static let chromeHelperPath = chromeBundle + "/Contents/Frameworks/Google Chrome Framework.framework/Versions/157.0/Helpers/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper"

    private static let xcodeBundle = "/Applications/Xcode.app"
    private static let xcodePath = xcodeBundle + "/Contents/MacOS/Xcode"
    private static let xcodeServiceBase = xcodeBundle + "/Contents/Developer"

    private static let safariBundle = "/Applications/Safari.app"
    private static let safariPath = safariBundle + "/Contents/MacOS/Safari"

    private static let teamsBundle = "/Applications/Microsoft Teams.app"
    private static let teamsPath = teamsBundle + "/Contents/MacOS/MSTeams"

    private static let codeBundle = "/Applications/Visual Studio Code.app"
    private static let codePath = codeBundle + "/Contents/MacOS/Electron"

    private static let claudeBundle = "/Applications/Claude.app"
    private static let claudePath = claudeBundle + "/Contents/MacOS/Claude"

    private static let zoomBundle = "/Applications/zoom.us.app"
    private static let zoomPath = zoomBundle + "/Contents/MacOS/zoom.us"

    private static let mailBundle = "/System/Applications/Mail.app"
    private static let mailPath = mailBundle + "/Contents/MacOS/Mail"

    private static let musicBundle = "/System/Applications/Music.app"
    private static let musicPath = musicBundle + "/Contents/MacOS/Music"

    private static let calendarBundle = "/System/Applications/Calendar.app"
    private static let calendarPath = calendarBundle + "/Contents/MacOS/Calendar"

    private static let terminalBundle = "/System/Applications/Utilities/Terminal.app"
    private static let terminalPath = terminalBundle + "/Contents/MacOS/Terminal"

    // MARK: - Sample process table

    private static let seeds: [Seed] = [
        // Google Chrome and its multiprocess architecture.
        Seed(pid: 4120, parentPID: 1, name: "Google Chrome", displayName: "Google Chrome",
             path: chromePath, appBundlePath: chromeBundle, bundleIdentifier: "com.google.Chrome",
             isApplicationRoot: true, kind: .application, cpu: 3.2, memoryMB: 410, threads: 28,
             startedMinutesAgo: 418),
        Seed(pid: 4292, parentPID: 4120, name: "Google Chrome Helper (GPU)",
             path: chromeHelperPath, appBundlePath: chromeBundle, kind: .renderer,
             cpu: 14.6, memoryMB: 380, threads: 24, startedMinutesAgo: 417),
        Seed(pid: 4311, parentPID: 4120, name: "Google Chrome Helper (Renderer)",
             path: chromeHelperPath, appBundlePath: chromeBundle, kind: .renderer,
             cpu: 25.4, memoryMB: 1_140, threads: 41, startedMinutesAgo: 417),
        Seed(pid: 4338, parentPID: 4120, name: "Google Chrome Helper (Renderer)",
             path: chromeHelperPath, appBundlePath: chromeBundle, kind: .renderer,
             cpu: 14.9, memoryMB: 780, threads: 33, startedMinutesAgo: 412),
        Seed(pid: 4350, parentPID: 4120, name: "Google Chrome Helper (Renderer)",
             path: chromeHelperPath, appBundlePath: chromeBundle, kind: .renderer,
             cpu: 7.6, memoryMB: 540, threads: 28, startedMinutesAgo: 404),
        Seed(pid: 4362, parentPID: 4120, name: "Google Chrome Helper (Network)",
             path: chromeHelperPath, appBundlePath: chromeBundle, kind: .service,
             cpu: 1.1, memoryMB: 130, threads: 12, startedMinutesAgo: 418),
        Seed(pid: 4377, parentPID: 4120, name: "Google Chrome Helper (Utility)",
             path: chromeHelperPath, appBundlePath: chromeBundle, kind: .helper,
             cpu: 0.6, memoryMB: 95, threads: 8, startedMinutesAgo: 417),

        // Xcode plus SourceKit, build service, and nested compiler workers.
        Seed(pid: 2256, parentPID: 1, name: "Xcode", displayName: "Xcode",
             path: xcodePath, appBundlePath: xcodeBundle, bundleIdentifier: "com.apple.dt.Xcode",
             isApplicationRoot: true, kind: .application, cpu: 3.6, memoryMB: 1_220, threads: 42,
             startedMinutesAgo: 96),
        Seed(pid: 2318, parentPID: 2256, name: "SourceKitService",
             path: xcodeServiceBase + "/Toolchains/XcodeDefault.xctoolchain/usr/lib/sourcekitd.framework/XPCServices/SourceKitService.xpc/Contents/MacOS/SourceKitService",
             appBundlePath: xcodeBundle, kind: .service,
             cpu: 21.8, memoryMB: 980, threads: 16, startedMinutesAgo: 95),
        Seed(pid: 3124, parentPID: 2256, name: "XCBBuildService",
             path: xcodeServiceBase + "/usr/bin/XCBBuildService",
             appBundlePath: xcodeBundle, kind: .service,
             cpu: 7.4, memoryMB: 320, threads: 18, startedMinutesAgo: 42),
        Seed(pid: 3140, parentPID: 3124, name: "swift-frontend",
             path: xcodeServiceBase + "/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-frontend",
             appBundlePath: xcodeBundle, kind: .helper,
             cpu: 3.1, memoryMB: 190, threads: 6, startedMinutesAgo: 6),
        Seed(pid: 3141, parentPID: 3124, name: "clang",
             path: xcodeServiceBase + "/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang",
             appBundlePath: xcodeBundle, kind: .helper,
             cpu: 1.2, memoryMB: 120, threads: 5, startedMinutesAgo: 5),
        Seed(pid: 2940, parentPID: 2256, name: "IBDesignablesAgent",
             path: xcodeServiceBase + "/Library/Xcode/Agents/IBDesignablesAgent.app/Contents/MacOS/IBDesignablesAgent",
             appBundlePath: xcodeBundle, kind: .helper,
             cpu: 0.3, memoryMB: 84, threads: 5, startedMinutesAgo: 74),
        Seed(pid: 3012, parentPID: 2256, name: "SimulatorTrampoline",
             path: xcodeServiceBase + "/Applications/Simulator.app/Contents/MacOS/SimulatorTrampoline",
             appBundlePath: xcodeBundle, kind: .helper,
             cpu: 0.1, memoryMB: 32, threads: 4, startedMinutesAgo: 63),

        // Safari and WebKit.
        Seed(pid: 1181, parentPID: 1, name: "Safari", displayName: "Safari",
             path: safariPath, appBundlePath: safariBundle, bundleIdentifier: "com.apple.Safari",
             isApplicationRoot: true, kind: .application, cpu: 1.4, memoryMB: 290, threads: 18,
             startedMinutesAgo: 204),
        Seed(pid: 1275, parentPID: 1181, name: "com.apple.WebKit.WebContent",
             path: "/System/Library/Frameworks/WebKit.framework/Versions/A/XPCServices/com.apple.WebKit.WebContent.xpc/Contents/MacOS/com.apple.WebKit.WebContent",
             kind: .renderer, cpu: 8.6, memoryMB: 760, threads: 24, startedMinutesAgo: 201),
        Seed(pid: 1290, parentPID: 1181, name: "com.apple.WebKit.WebContent",
             path: "/System/Library/Frameworks/WebKit.framework/Versions/A/XPCServices/com.apple.WebKit.WebContent.xpc/Contents/MacOS/com.apple.WebKit.WebContent",
             kind: .renderer, cpu: 3.4, memoryMB: 510, threads: 21, startedMinutesAgo: 178),
        Seed(pid: 1260, parentPID: 1181, name: "com.apple.WebKit.Networking",
             path: "/System/Library/Frameworks/WebKit.framework/Versions/A/XPCServices/com.apple.WebKit.Networking.xpc/Contents/MacOS/com.apple.WebKit.Networking",
             kind: .service, cpu: 0.2, memoryMB: 95, threads: 8, startedMinutesAgo: 204),
        Seed(pid: 1266, parentPID: 1181, name: "com.apple.WebKit.GPU",
             path: "/System/Library/Frameworks/WebKit.framework/Versions/A/XPCServices/com.apple.WebKit.GPU.xpc/Contents/MacOS/com.apple.WebKit.GPU",
             kind: .renderer, cpu: 1.7, memoryMB: 240, threads: 14, startedMinutesAgo: 204),

        // Microsoft Teams.
        Seed(pid: 5802, parentPID: 1, name: "MSTeams", displayName: "Microsoft Teams",
             path: teamsPath, appBundlePath: teamsBundle, bundleIdentifier: "com.microsoft.teams2",
             isApplicationRoot: true, kind: .application, cpu: 2.1, memoryMB: 590, threads: 38,
             startedMinutesAgo: 312),
        Seed(pid: 5820, parentPID: 5802, name: "Microsoft Teams Helper (Renderer)",
             path: teamsBundle + "/Contents/Frameworks/Microsoft Teams Helper (Renderer).app/Contents/MacOS/Microsoft Teams Helper (Renderer)",
             appBundlePath: teamsBundle, kind: .renderer,
             cpu: 11.2, memoryMB: 520, threads: 33, startedMinutesAgo: 311),
        Seed(pid: 5831, parentPID: 5802, name: "Microsoft Teams Helper (GPU)",
             path: teamsBundle + "/Contents/Frameworks/Microsoft Teams Helper (GPU).app/Contents/MacOS/Microsoft Teams Helper (GPU)",
             appBundlePath: teamsBundle, kind: .renderer,
             cpu: 4.8, memoryMB: 330, threads: 24, startedMinutesAgo: 311),
        Seed(pid: 5840, parentPID: 5802, name: "Microsoft Teams Helper (Network)",
             path: teamsBundle + "/Contents/Frameworks/Microsoft Teams Helper (Network).app/Contents/MacOS/Microsoft Teams Helper (Network)",
             appBundlePath: teamsBundle, kind: .service,
             cpu: 0.9, memoryMB: 115, threads: 10, startedMinutesAgo: 311),

        // Visual Studio Code (Electron main binary is named "Electron").
        Seed(pid: 4601, parentPID: 1, name: "Electron", displayName: "Visual Studio Code",
             path: codePath, appBundlePath: codeBundle, bundleIdentifier: "com.microsoft.VSCode",
             isApplicationRoot: true, kind: .application, cpu: 2.2, memoryMB: 470, threads: 30,
             startedMinutesAgo: 155),
        Seed(pid: 4620, parentPID: 4601, name: "Code Helper (Renderer)",
             path: codeBundle + "/Contents/Frameworks/Code Helper (Renderer).app/Contents/MacOS/Code Helper (Renderer)",
             appBundlePath: codeBundle, kind: .renderer,
             cpu: 6.8, memoryMB: 520, threads: 33, startedMinutesAgo: 154),
        Seed(pid: 4633, parentPID: 4601, name: "Code Helper (Plugin)",
             path: codeBundle + "/Contents/Frameworks/Code Helper (Plugin).app/Contents/MacOS/Code Helper (Plugin)",
             appBundlePath: codeBundle, kind: .helper,
             cpu: 4.4, memoryMB: 410, threads: 26, startedMinutesAgo: 154),
        Seed(pid: 4645, parentPID: 4601, name: "Code Helper (GPU)",
             path: codeBundle + "/Contents/Frameworks/Code Helper (GPU).app/Contents/MacOS/Code Helper (GPU)",
             appBundlePath: codeBundle, kind: .renderer,
             cpu: 1.5, memoryMB: 180, threads: 12, startedMinutesAgo: 154),
        Seed(pid: 4651, parentPID: 4633, name: "tsserver",
             path: codeBundle + "/Contents/Resources/app/extensions/node_modules/typescript/lib/tsserver.js",
             appBundlePath: codeBundle, kind: .service,
             cpu: 1.3, memoryMB: 150, threads: 8, startedMinutesAgo: 92),

        // Claude desktop.
        Seed(pid: 6150, parentPID: 1, name: "Claude", displayName: "Claude",
             path: claudePath, appBundlePath: claudeBundle, bundleIdentifier: "com.anthropic.claudefordesktop",
             isApplicationRoot: true, kind: .application, cpu: 4.4, memoryMB: 540, threads: 22,
             startedMinutesAgo: 61),
        Seed(pid: 6166, parentPID: 6150, name: "Claude Helper (Renderer)",
             path: claudeBundle + "/Contents/Frameworks/Claude Helper (Renderer).app/Contents/MacOS/Claude Helper (Renderer)",
             appBundlePath: claudeBundle, kind: .renderer,
             cpu: 2.9, memoryMB: 310, threads: 20, startedMinutesAgo: 60),

        // Zoom.
        Seed(pid: 6310, parentPID: 1, name: "zoom.us", displayName: "Zoom",
             path: zoomPath, appBundlePath: zoomBundle, bundleIdentifier: "us.zoom.xos",
             isApplicationRoot: true, kind: .application, cpu: 1.2, memoryMB: 280, threads: 24,
             startedMinutesAgo: 845),
        Seed(pid: 6322, parentPID: 6310, name: "CptHost",
             path: zoomBundle + "/Contents/Frameworks/cpthost.app/Contents/MacOS/CptHost",
             appBundlePath: zoomBundle, kind: .helper,
             cpu: 3.6, memoryMB: 265, threads: 15, startedMinutesAgo: 20),

        // Apple Mail.
        Seed(pid: 1207, parentPID: 1, name: "Mail", displayName: "Mail",
             path: mailPath, appBundlePath: mailBundle, bundleIdentifier: "com.apple.mail",
             isApplicationRoot: true, kind: .application, cpu: 0.6, memoryMB: 200, threads: 16,
             startedMinutesAgo: 487),
        Seed(pid: 1219, parentPID: 1207, name: "com.apple.WebKit.WebContent",
             path: "/System/Library/Frameworks/WebKit.framework/Versions/A/XPCServices/com.apple.WebKit.WebContent.xpc/Contents/MacOS/com.apple.WebKit.WebContent",
             kind: .renderer, cpu: 1.2, memoryMB: 175, threads: 12, startedMinutesAgo: 480),

        // Music.
        Seed(pid: 1244, parentPID: 1, name: "Music", displayName: "Music",
             path: musicPath, appBundlePath: musicBundle, bundleIdentifier: "com.apple.Music",
             isApplicationRoot: true, kind: .application, cpu: 0.7, memoryMB: 160, threads: 14,
             startedMinutesAgo: 1_102),
        Seed(pid: 1250, parentPID: 1244, name: "MusicCacheExtension",
             path: musicBundle + "/Contents/PlugIns/MusicCacheExtension.appex/Contents/MacOS/MusicCacheExtension",
             appBundlePath: musicBundle, kind: .service,
             cpu: 0.3, memoryMB: 110, threads: 9, startedMinutesAgo: 1_100),

        // Calendar.
        Seed(pid: 1382, parentPID: 1, name: "Calendar", displayName: "Calendar",
             path: calendarPath, appBundlePath: calendarBundle, bundleIdentifier: "com.apple.iCal",
             isApplicationRoot: true, kind: .application, cpu: 0.3, memoryMB: 90, threads: 9,
             startedMinutesAgo: 619),
        Seed(pid: 1390, parentPID: 1382, name: "CalendarCache",
             path: calendarBundle + "/Contents/PlugIns/CalendarCache.appex/Contents/MacOS/CalendarCache",
             appBundlePath: calendarBundle, kind: .service,
             cpu: 0.2, memoryMB: 60, threads: 5, startedMinutesAgo: 618),

        // Terminal with a small development server tree.
        Seed(pid: 7120, parentPID: 1, name: "Terminal", displayName: "Terminal",
             path: terminalPath, appBundlePath: terminalBundle, bundleIdentifier: "com.apple.Terminal",
             isApplicationRoot: true, kind: .application, cpu: 0.2, memoryMB: 145, threads: 8,
             startedMinutesAgo: 238),
        Seed(pid: 7140, parentPID: 7120, name: "zsh",
             path: "/bin/zsh", kind: .helper,
             cpu: 0.1, memoryMB: 12, threads: 2, startedMinutesAgo: 238),
        Seed(pid: 7152, parentPID: 7140, name: "node",
             path: "/opt/homebrew/bin/node", kind: .service,
             cpu: 2.7, memoryMB: 315, threads: 12, startedMinutesAgo: 133),
        Seed(pid: 7164, parentPID: 7152, name: "esbuild",
             path: "/opt/homebrew/bin/esbuild", kind: .helper,
             cpu: 1.1, memoryMB: 95, threads: 6, startedMinutesAgo: 12),

        // Unassigned background processes. These must never appear as groups.
        Seed(pid: 1, parentPID: 0, name: "launchd", path: "/sbin/launchd",
             kind: .daemon, cpu: 0.1, memoryMB: 24, threads: 3, startedMinutesAgo: 2_880),
        Seed(pid: 214, parentPID: 1, name: "WindowServer", path: "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/Resources/WindowServer",
             kind: .daemon, cpu: 3.2, memoryMB: 310, threads: 18, startedMinutesAgo: 2_880),
        Seed(pid: 771, parentPID: 1, name: "MenuBarAgent",
             path: "/System/Library/CoreServices/MenuBarAgent.app/Contents/MacOS/MenuBarAgent",
             appBundlePath: "/System/Library/CoreServices/MenuBarAgent.app",
             bundleIdentifier: "com.apple.MenuBarAgent", kind: .daemon,
             cpu: 0.4, memoryMB: 55, threads: 5, startedMinutesAgo: 2_879),
        Seed(pid: 241, parentPID: 1, name: "UserEventAgent", path: "/usr/libexec/UserEventAgent",
             kind: .daemon, cpu: 0.0, memoryMB: 14, threads: 4, startedMinutesAgo: 2_880),
        Seed(pid: 559, parentPID: 1, name: "softwareupdated", path: "/System/Library/PrivateFrameworks/SoftwareUpdate.framework/Versions/A/Resources/softwareupdated",
             kind: .daemon, cpu: 0.0, memoryMB: 38, threads: 6, startedMinutesAgo: 2_875)
    ]

    /// Builds an immutable snapshot. With `jitter` off, values are exact and
    /// deterministic, which keeps tests and previews stable.
    static func makeSnapshot(jitter: Bool, date: Date = Date()) -> ProcessSnapshot {
        let processes = seeds.map { seed -> MonitoredProcess in
            let cpu = jitter ? max(0, seed.cpu * Double.random(in: 0.86...1.16)) : seed.cpu
            let memoryMB = jitter
                ? max(1, seed.memoryMB * Double.random(in: 0.97...1.035))
                : seed.memoryMB
            let threads = jitter && seed.threads > 3
                ? max(1, seed.threads + Int.random(in: -1...2))
                : seed.threads

            return MonitoredProcess(
                pid: seed.pid,
                parentPID: seed.parentPID,
                name: seed.name,
                displayName: seed.displayName,
                executablePath: seed.path,
                appBundlePath: seed.appBundlePath,
                bundleIdentifier: seed.bundleIdentifier,
                isApplicationRoot: seed.isApplicationRoot,
                kind: seed.kind,
                metrics: ResourceMetrics(
                    cpuPercent: cpu,
                    memoryBytes: UInt64(memoryMB * 1_048_576),
                    threadCount: threads,
                    diskBytesPerSecond: 0,
                    energyImpact: cpu * 0.8
                ),
                startDate: date.addingTimeInterval(-seed.startedMinutesAgo * 60),
                userName: NSUserName()
            )
        }

        return ProcessSnapshot(
            processes: processes,
            timestamp: date,
            hiddenBackgroundProcessCount: additionalHiddenBackgroundCount,
            hostMemoryBytes: hostMemoryBytes,
            logicalCoreCount: logicalCoreCount,
            sourceDescription: "Mock workspace"
        )
    }
}

/// A tiny, deterministic provider for SwiftUI previews and unit tests. It never
/// touches libproc and is never used by the shipping app.
struct MockProcessDataProvider: ProcessDataProviding {
    var jitter: Bool = true

    func fetchSnapshot() async throws -> ProcessSnapshot {
        MockScenario.makeSnapshot(jitter: jitter)
    }
}
