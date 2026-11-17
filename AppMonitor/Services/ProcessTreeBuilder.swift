import Foundation

/// The result of turning a flat process table into user-facing application trees.
struct ProcessTreeBuildResult: Sendable {
    let groups: [ApplicationGroup]

    /// Number of processes from the snapshot that were not attached to any
    /// user-facing application tree. These are the background agents and
    /// standalone daemons AppMonitor intentionally leaves out. The number is
    /// surfaced in the sidebar so the filtering never feels like missing data.
    let excludedProcessCount: Int

    var includedProcessCount: Int {
        groups.reduce(0) { $0 + $1.processCount }
    }
}

/// Builds the parent/child hierarchy that powers the main list.
///
/// The algorithm has two passes:
/// 1. Walk the actual PPID tree from every application root. This is the most
///    accurate relationship and handles nested workers (for example, a Swift
///    compiler launched by an Xcode build service).
/// 2. Adopt any still-unclaimed process whose executable lives inside the same
///    `.app` bundle. Some XPC services and launch agents are re-parented to
///    `launchd` by the system, but they still logically belong to the app.
///    Anything left over is a standalone background process and is excluded.
struct ProcessTreeBuilder {
    private struct PartialGroup {
        let root: MonitoredProcess
        var descendants: [GroupedProcess]
    }

    func build(from processes: [MonitoredProcess]) -> ProcessTreeBuildResult {
        // Deduplicate defensively. A process table can theoretically expose the
        // same PID twice while processes are exiting.
        var seenPIDs = Set<Int32>()
        let uniqueProcesses = processes.filter { seenPIDs.insert($0.pid).inserted }

        let roots = uniqueProcesses
            .filter(\.isApplicationRoot)
            .sorted { $0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending }

        let nonRoots = uniqueProcesses.filter { !$0.isApplicationRoot }
        let childrenByParent = Dictionary(grouping: nonRoots, by: \.parentPID)

        var claimedPIDs = Set<Int32>()
        var partialGroups: [PartialGroup] = []

        // Pass 1: build each root's true process tree.
        for root in roots {
            var visited = Set<Int32>([root.pid])
            claimedPIDs.insert(root.pid)
            var descendants: [GroupedProcess] = []

            func appendSubtree(of parentPID: Int32, depth: Int) {
                let children = (childrenByParent[parentPID] ?? [])
                    .filter { !visited.contains($0.pid) }
                    .sorted(by: Self.resourceOrder)

                for child in children {
                    visited.insert(child.pid)
                    claimedPIDs.insert(child.pid)
                    descendants.append(GroupedProcess(process: child, depth: depth))
                    appendSubtree(of: child.pid, depth: depth + 1)
                }
            }

            appendSubtree(of: root.pid, depth: 0)
            partialGroups.append(PartialGroup(root: root, descendants: descendants))
        }

        // Pass 2: adopt orphaned helpers that live inside the same app bundle.
        //
        // We deliberately do not adopt an unassigned process merely because its
        // name contains the app's name. Bundle containment is a much stronger
        // signal, and it prevents unrelated launch agents from being pulled in.
        for index in partialGroups.indices {
            let root = partialGroups[index].root
            guard let appBundlePath = root.appBundlePath, !appBundlePath.isEmpty else { continue }

            var alreadyInGroup = Set(partialGroups[index].descendants.map(\.process.pid))
            let candidates = nonRoots
                .filter {
                    !claimedPIDs.contains($0.pid) &&
                        !alreadyInGroup.contains($0.pid) &&
                        Self.isProcess($0, insideAppBundleAt: appBundlePath)
                }
                .sorted(by: Self.resourceOrder)

            for candidate in candidates {
                guard !claimedPIDs.contains(candidate.pid) else { continue }
                claimedPIDs.insert(candidate.pid)
                alreadyInGroup.insert(candidate.pid)
                partialGroups[index].descendants.append(
                    GroupedProcess(process: candidate, depth: 0)
                )

                // Adopt the candidate's own children too, unless another app's
                // first pass already claimed them.
                appendAdoptedSubtree(
                    of: candidate.pid,
                    depth: 1,
                    childrenByParent: childrenByParent,
                    claimedPIDs: &claimedPIDs,
                    descendants: &partialGroups[index].descendants
                )
            }
        }

        let groups = partialGroups.map { partial -> ApplicationGroup in
            // `metrics` includes the root plus every descendant, computed once.
            var metrics = partial.root.metrics
            for entry in partial.descendants {
                metrics += entry.process.metrics
            }

            return ApplicationGroup(
                id: "\(partial.root.bundleIdentifier ?? partial.root.name)-\(partial.root.pid)",
                application: partial.root,
                descendants: partial.descendants,
                metrics: metrics
            )
        }

        let includedCount = groups.reduce(0) { $0 + $1.processCount }
        let excludedCount = max(0, uniqueProcesses.count - includedCount)

        return ProcessTreeBuildResult(
            groups: groups,
            excludedProcessCount: excludedCount
        )
    }

    /// Sort siblings by CPU descending so the busiest helper appears first, then
    /// fall back to memory and PID for a deterministic order.
    private static func resourceOrder(_ lhs: MonitoredProcess, _ rhs: MonitoredProcess) -> Bool {
        if lhs.metrics.cpuPercent != rhs.metrics.cpuPercent {
            return lhs.metrics.cpuPercent > rhs.metrics.cpuPercent
        }
        if lhs.metrics.memoryBytes != rhs.metrics.memoryBytes {
            return lhs.metrics.memoryBytes > rhs.metrics.memoryBytes
        }
        return lhs.pid < rhs.pid
    }

    private static func isProcess(_ process: MonitoredProcess, insideAppBundleAt bundlePath: String) -> Bool {
        let normalizedBundle = URL(fileURLWithPath: bundlePath).standardizedFileURL.path
        let paths = [process.executablePath, process.appBundlePath].compactMap { $0 }
        return paths.contains { path in
            let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
            return normalized == normalizedBundle || normalized.hasPrefix(normalizedBundle + "/")
        }
    }

    private func appendAdoptedSubtree(
        of parentPID: Int32,
        depth: Int,
        childrenByParent: [Int32: [MonitoredProcess]],
        claimedPIDs: inout Set<Int32>,
        descendants: inout [GroupedProcess]
    ) {
        let children = (childrenByParent[parentPID] ?? [])
            .filter { !claimedPIDs.contains($0.pid) }
            .sorted(by: Self.resourceOrder)

        for child in children {
            claimedPIDs.insert(child.pid)
            descendants.append(GroupedProcess(process: child, depth: depth))
            appendAdoptedSubtree(
                of: child.pid,
                depth: depth + 1,
                childrenByParent: childrenByParent,
                claimedPIDs: &claimedPIDs,
                descendants: &descendants
            )
        }
    }
}
