import Foundation
import SwiftUI

/// Centralized text formatting. Values are deliberately compact enough to fit
/// through the sort columns without jitter as numbers change.
enum MetricFormatter {
    static func cpu(_ percent: Double) -> String {
        if percent >= 100 {
            return String(format: "%.0f%%", percent)
        }
        return String(format: "%.1f%%", percent)
    }

    static func memory(_ bytes: UInt64) -> String {
        let gibibytes = Double(bytes) / 1_073_741_824
        if gibibytes >= 10 {
            return String(format: "%.1f GB", gibibytes)
        }
        if gibibytes >= 1 {
            return String(format: "%.2f GB", gibibytes)
        }
        let mebibytes = Double(bytes) / 1_048_576
        if mebibytes >= 100 {
            return String(format: "%.0f MB", mebibytes)
        }
        return String(format: "%.1f MB", mebibytes)
    }

    static func memoryShare(_ bytes: UInt64, hostMemory: UInt64) -> String {
        guard hostMemory > 0 else { return "0%" }
        let share = Double(bytes) / Double(hostMemory) * 100
        if share < 0.1 {
            return "<0.1%"
        }
        return String(format: "%.1f%%", share)
    }

    static func threadCount(_ count: Int) -> String {
        count == 1 ? "1 thread" : "\(count) threads"
    }

    static func processCount(_ count: Int) -> String {
        count == 1 ? "1 process" : "\(count) processes"
    }

    static func pid(_ pid: Int32) -> String {
        String(pid)
    }

    static func started(_ date: Date?) -> String {
        guard let date else { return "Unknown" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    static func hostedMemory(_ bytes: UInt64) -> String {
        let gibibytes = Double(bytes) / 1_073_741_824
        return String(format: "%.0f GB", gibibytes)
    }
}

/// Semantic colors used consistently by list bars, detail cards, and charts.
enum MetricPalette {
    static let cpu = Color.teal
    static let memory = Color.indigo
    static let favorite = Color.yellow

    static func cpuTint(for percent: Double) -> Color {
        if percent >= 50 { return .red }
        if percent >= 20 { return .orange }
        return .teal
    }

    static func memoryTint(for bytes: UInt64) -> Color {
        let gibibytes = Double(bytes) / 1_073_741_824
        if gibibytes >= 3 { return .red }
        if gibibytes >= 1.5 { return .orange }
        return .indigo
    }

    static func tint(for kind: ProcessKind) -> Color {
        switch kind {
        case .application: return .accentColor
        case .renderer: return .blue
        case .helper: return .teal
        case .service: return .indigo
        case .daemon: return .secondary
        }
    }

    static func tint(for filter: SidebarFilter) -> Color {
        switch filter {
        case .all: return .accentColor
        case .highCPU: return .orange
        case .highMemory: return .purple
        case .favorites: return .yellow
        }
    }
}

/// Shared layout constants keep the list row and column header in perfect
/// alignment even though they are separate views.
enum ProcessListLayout {
    static let outerHorizontalPadding: CGFloat = 12
    static let cardHorizontalPadding: CGFloat = 14
    static let cardTrailingPadding: CGFloat = 16
    static let cpuColumnWidth: CGFloat = 76
    static let memoryColumnWidth: CGFloat = 92
    static let columnSpacing: CGFloat = 14
    static let headerTrailingPadding: CGFloat = 28

    static var metricColumnsWidth: CGFloat {
        cpuColumnWidth + memoryColumnWidth + columnSpacing
    }
}
