import Foundation

/// The metric used to rank applications. Choosing a key re-ranks the main list
/// once; automatic refreshes never move rows afterward.
enum ProcessSortKey: String, CaseIterable, Identifiable, Sendable {
    case cpu
    case memory
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .name: return "Name"
        }
    }

    var columnTitle: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .name: return "Application"
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .cpu: return "Re-rank once by CPU usage, highest first"
        case .memory: return "Re-rank once by memory footprint, highest first"
        case .name: return "Re-rank once alphabetically by application name"
        }
    }
}

/// Sidebar smart filters. These are intentionally simple, explainable rules
/// rather than opaque heuristics:
/// - High CPU: applications currently using at least 10% of one core.
/// - High Memory: applications with a footprint of at least 1 GB.
/// - Favorites: applications explicitly pinned by the user.
enum SidebarFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case highCPU
    case highMemory
    case favorites

    var id: String { rawValue }

    static let highCPUThreshold: Double = 10
    static let highMemoryThreshold: UInt64 = 1_073_741_824 // 1 GiB

    var title: String {
        switch self {
        case .all: return "All Applications"
        case .highCPU: return "High CPU"
        case .highMemory: return "High Memory"
        case .favorites: return "Favorites"
        }
    }

    var headline: String {
        switch self {
        case .all: return "Applications"
        case .highCPU: return "High CPU Impact"
        case .highMemory: return "High Memory Footprint"
        case .favorites: return "Favorites"
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .highCPU: return "flame.fill"
        case .highMemory: return "memorychip.fill"
        case .favorites: return "star.fill"
        }
    }

    var emptyTitle: String {
        switch self {
        case .all: return "No Applications Found"
        case .highCPU: return "No High-CPU Applications"
        case .highMemory: return "No High-Memory Applications"
        case .favorites: return "No Favorites Yet"
        }
    }

    var emptyDescription: String {
        switch self {
        case .all: return "AppMonitor could not find any user-facing applications to display."
        case .highCPU: return "No application is currently using more than 10% of a CPU core."
        case .highMemory: return "No application currently has a memory footprint above 1 GB."
        case .favorites: return "Star an application in its detail panel to keep it close at hand."
        }
    }

    func includes(_ group: ApplicationGroup, isFavorite: Bool) -> Bool {
        switch self {
        case .all:
            return true
        case .highCPU:
            return group.metrics.cpuPercent >= Self.highCPUThreshold
        case .highMemory:
            return group.metrics.memoryBytes >= Self.highMemoryThreshold
        case .favorites:
            return isFavorite
        }
    }
}

