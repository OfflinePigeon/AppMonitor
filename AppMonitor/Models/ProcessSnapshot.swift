import Foundation

/// One complete collection pass over the process table.
///
/// Keeping snapshots immutable makes refresh races impossible: the view model
/// simply replaces its grouped model with a new, fully consistent snapshot.
struct ProcessSnapshot: Hashable, Sendable {
    let processes: [MonitoredProcess]
    let timestamp: Date

    /// Number of system-wide background processes that were known to exist but
    /// were intentionally not included in `processes` (for example, processes
    /// owned by other users or processes the provider cannot inspect).
    /// Standalone agents included in `processes` are counted separately by the
    /// grouping layer, so nothing is hidden without a trace.
    let hiddenBackgroundProcessCount: Int
    let hostMemoryBytes: UInt64
    let logicalCoreCount: Int
    let sourceDescription: String

    init(
        processes: [MonitoredProcess],
        timestamp: Date = Date(),
        hiddenBackgroundProcessCount: Int = 0,
        hostMemoryBytes: UInt64,
        logicalCoreCount: Int,
        sourceDescription: String
    ) {
        self.processes = processes
        self.timestamp = timestamp
        self.hiddenBackgroundProcessCount = hiddenBackgroundProcessCount
        self.hostMemoryBytes = hostMemoryBytes
        self.logicalCoreCount = logicalCoreCount
        self.sourceDescription = sourceDescription
    }
}
