import Foundation

/// The role a process plays inside an application's process tree.
///
/// The classification is intentionally presentation-friendly: helpers and
/// renderers are user-facing children of an app, while daemons and agents are
/// the kind of unassigned background work AppMonitor deliberately filters out.
enum ProcessKind: String, Hashable, Sendable, CaseIterable {
    case application
    case helper
    case renderer
    case service
    case daemon

    var title: String {
        switch self {
        case .application: return "Application"
        case .helper: return "Helper"
        case .renderer: return "Renderer"
        case .service: return "Service"
        case .daemon: return "Background"
        }
    }

    var symbolName: String {
        switch self {
        case .application: return "app.fill"
        case .helper: return "gearshape.2.fill"
        case .renderer: return "square.stack.3d.up.fill"
        case .service: return "wrench.and.screwdriver.fill"
        case .daemon: return "shield.lefthalf.filled"
        }
    }
}

/// A single process snapshot, normalized so it can come from either the mock
/// service or the live libproc-backed provider.
///
/// `isApplicationRoot` marks processes that present a normal Dock user
/// interface (`NSApplicationActivationPolicy.regular`). Only those roots and
/// their descendants become top-level entries in AppMonitor.
struct MonitoredProcess: Identifiable, Hashable, Sendable {
    let pid: Int32
    let parentPID: Int32
    let name: String
    let displayName: String?
    let executablePath: String?
    let appBundlePath: String?
    let bundleIdentifier: String?
    let isApplicationRoot: Bool
    let kind: ProcessKind
    let metrics: ResourceMetrics
    let startDate: Date?
    let userName: String

    var id: Int32 { pid }

    /// The best user-facing label for the process. Electron apps often expose a
    /// binary named "Electron"; `displayName` lets the live bridge substitute
    /// "Visual Studio Code" from `NSRunningApplication.localizedName`.
    var displayTitle: String {
        displayName ?? name
    }

    init(
        pid: Int32,
        parentPID: Int32,
        name: String,
        displayName: String? = nil,
        executablePath: String? = nil,
        appBundlePath: String? = nil,
        bundleIdentifier: String? = nil,
        isApplicationRoot: Bool = false,
        kind: ProcessKind = .helper,
        metrics: ResourceMetrics = .zero,
        startDate: Date? = nil,
        userName: String = NSUserName()
    ) {
        self.pid = pid
        self.parentPID = parentPID
        self.name = name
        self.displayName = displayName
        self.executablePath = executablePath
        self.appBundlePath = appBundlePath
        self.bundleIdentifier = bundleIdentifier
        self.isApplicationRoot = isApplicationRoot
        self.kind = kind
        self.metrics = metrics
        self.startDate = startDate
        self.userName = userName
    }
}
