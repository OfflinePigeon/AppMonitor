import Foundation

/// A point-in-time resource sample for one process or an aggregated process tree.
///
/// CPU is expressed the way Activity Monitor expresses it: `100` means one fully
/// utilized logical core. A multi-threaded app can therefore report values above
/// 100 percent. Memory is the process's physical footprint (dirty + compressed +
/// swapped pages), not merely its resident set size.
struct ResourceMetrics: Hashable, Sendable {
    var cpuPercent: Double
    var memoryBytes: UInt64
    var threadCount: Int
    var diskBytesPerSecond: Double
    var energyImpact: Double

    init(
        cpuPercent: Double = 0,
        memoryBytes: UInt64 = 0,
        threadCount: Int = 0,
        diskBytesPerSecond: Double = 0,
        energyImpact: Double = 0
    ) {
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
        self.threadCount = threadCount
        self.diskBytesPerSecond = diskBytesPerSecond
        self.energyImpact = energyImpact
    }

    static let zero = ResourceMetrics()

    /// Adds two samples. CPU and disk throughput are additive thanks to their
    /// per-second normalization. Thread counts are additive as well.
    static func + (lhs: ResourceMetrics, rhs: ResourceMetrics) -> ResourceMetrics {
        ResourceMetrics(
            cpuPercent: lhs.cpuPercent + rhs.cpuPercent,
            memoryBytes: lhs.memoryBytes + rhs.memoryBytes,
            threadCount: lhs.threadCount + rhs.threadCount,
            diskBytesPerSecond: lhs.diskBytesPerSecond + rhs.diskBytesPerSecond,
            energyImpact: lhs.energyImpact + rhs.energyImpact
        )
    }

    static func += (lhs: inout ResourceMetrics, rhs: ResourceMetrics) {
        lhs = lhs + rhs
    }
}
