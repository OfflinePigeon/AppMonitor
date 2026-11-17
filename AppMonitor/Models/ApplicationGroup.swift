import Foundation

/// A process placed inside a group, together with its tree depth.
///
/// Depth `0` is a direct helper of the application. Depth `1+` represents
/// XPC services, compiler workers, or renderer sub-processes that sit further
/// down the process tree. The list indents these rows to make the relationship
/// legible without a second disclosure level.
struct GroupedProcess: Identifiable, Hashable, Sendable {
    let process: MonitoredProcess
    let depth: Int

    var id: Int32 { process.pid }
    var title: String { process.displayTitle }
}

/// A user-facing application and every process that belongs to it.
///
/// `metrics` is aggregated once, at build time, so SwiftUI never has to walk
/// the descendant list while scrolling.
struct ApplicationGroup: Identifiable, Hashable, Sendable {
    let id: String
    let application: MonitoredProcess
    let descendants: [GroupedProcess]
    let metrics: ResourceMetrics

    var displayName: String { application.displayTitle }
    var bundleIdentifier: String? { application.bundleIdentifier }
    var processCount: Int { descendants.count + 1 }
    var threadCount: Int { metrics.threadCount }

    /// Root first, then descendants in display order.
    var allEntries: [GroupedProcess] {
        [GroupedProcess(process: application, depth: 0)] + descendants
    }

    var allProcesses: [MonitoredProcess] {
        [application] + descendants.map(\.process)
    }

    func matches(searchText query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }

        if displayName.localizedCaseInsensitiveContains(needle) ||
            (bundleIdentifier?.localizedCaseInsensitiveContains(needle) ?? false) ||
            (application.executablePath?.localizedCaseInsensitiveContains(needle) ?? false) ||
            String(application.pid).contains(needle) {
            return true
        }

        return descendants.contains { entry in
            entry.process.name.localizedCaseInsensitiveContains(needle) ||
                entry.process.displayTitle.localizedCaseInsensitiveContains(needle) ||
                String(entry.process.pid).contains(needle)
        }
    }

    /// Number of descendant processes matching a search query. Used for the
    /// "3 matching processes" hint on collapsed search results.
    func matchingDescendantCount(for query: String) -> Int {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return 0 }
        return descendants.filter {
            $0.process.name.localizedCaseInsensitiveContains(needle) ||
                String($0.process.pid).contains(needle)
        }.count
    }
}
