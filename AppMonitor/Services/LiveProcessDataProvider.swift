import AppKit
import Darwin
import Foundation

/// Live process-table bridge for production.
///
/// ---------------------------------------------------------------------------
/// How to connect real macOS APIs
/// ---------------------------------------------------------------------------
/// This provider supplies the shipping app; `MockProcessDataProvider` exists
/// only for previews and tests. The UI, grouping, sorting, and filtering depend
/// on `ProcessDataProviding.fetchSnapshot()`. This file is a complete reference
/// implementation using public, non-privileged APIs:
///
/// 1. **User-facing apps** — `NSWorkspace.shared.runningApplications` exposes
///    `processIdentifier`, `localizedName`, `bundleIdentifier`, and `bundleURL`.
///    Filtering to `activationPolicy == .regular` and `!isTerminated` yields
///    the same set of Dock-visible apps that Activity Monitor calls "apps".
/// 2. **All PIDs** — `proc_listpids(PROC_ALL_PIDS, ...)` returns the process
///    table. No root access is needed for processes owned by the current user.
/// 3. **Per-process metadata** — `proc_pidpath`, `proc_name`, and
///    `proc_pidinfo(PROC_PIDTBSDINFO)` provide the executable path, name, PPID,
///    UID, and start time.
/// 4. **Resource metrics** — `proc_pid_rusage` returns cumulative CPU time and
///    `ri_phys_footprint` (the same physical footprint Activity Monitor uses),
///    while `proc_pidinfo(PROC_PIDTASKINFO)` supplies the thread count.
///
/// CPU percentages require a delta: rusage values are cumulative, so the first
/// sample for a PID reports 0%. Subsequent samples divide the change in CPU
/// seconds by wall-clock elapsed time. A multi-threaded process can exceed
/// 100%, exactly like Activity Monitor.
///
/// **Sandboxing:** libproc process inspection is blocked by the App Sandbox for
/// processes other than your own. This app sets `ENABLE_APP_SANDBOX = NO`. For
/// Mac App Store distribution you would keep the UI sandboxed and move system
/// sampling into a privileged XPC helper, or restrict the feature set.
///
/// **Fallback:** any PID that cannot be inspected (for example, another user's
/// process, or a system entitlement-protected process) is skipped rather than
/// failing the entire refresh. The remaining apps still update normally.
///
/// **Grouping:** this provider deliberately returns the flat process table plus
/// app-root metadata. Hierarchy remains the responsibility of
/// `ProcessTreeBuilder`, which walks PPIDs and then adopts bundle-contained
/// orphans. That keeps grouping logic testable with mock data and reusable if
/// you replace libproc with `sysctl` or EndpointSecurity later.
actor LiveProcessDataProvider: ProcessDataProviding {
    private struct CPUSample {
        let cpuSeconds: Double
        let timestamp: Date
    }

    private struct RunningAppMetadata: Sendable {
        let pid: Int32
        let name: String?
        let bundleIdentifier: String?
        let bundlePath: String?
    }

    private var previousSamples: [Int32: CPUSample] = [:]
    private var hasPrimedCPUSample = false

    func fetchSnapshot() async throws -> ProcessSnapshot {
        // The first collection only establishes a CPU baseline, which would
        // leave the initial list at 0% and force a visible re-rank a moment
        // later. Take one short bridging sample so the first rendered order is
        // already meaningful, then keep the normal cadence.
        if !hasPrimedCPUSample {
            _ = try await collectSnapshot()
            try await Task.sleep(nanoseconds: 1_000_000_000)
            hasPrimedCPUSample = true
        }

        return try await collectSnapshot()
    }

    private func collectSnapshot() async throws -> ProcessSnapshot {
        let now = Date()

        // NSWorkspace is an AppKit API; reading it on the main actor is safest.
        let runningApps = await MainActor.run { () -> [RunningAppMetadata] in
            NSWorkspace.shared.runningApplications
                .filter { app in
                    app.activationPolicy == .regular &&
                        app.processIdentifier > 0 &&
                        !app.isTerminated
                }
                .map { app in
                    RunningAppMetadata(
                        pid: app.processIdentifier,
                        name: app.localizedName,
                        bundleIdentifier: app.bundleIdentifier,
                        bundlePath: app.bundleURL?.path
                    )
                }
        }

        let appsByPID = Dictionary(
            runningApps.map { ($0.pid, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let appBundlePaths = runningApps.compactMap(\.bundlePath)

        let pids = Self.allProcessIDs()
        guard !pids.isEmpty else {
            throw ProcessDataError.processEnumerationFailed
        }

        var processes: [MonitoredProcess] = []
        processes.reserveCapacity(pids.count)
        var newSamples: [Int32: CPUSample] = [:]
        newSamples.reserveCapacity(pids.count)

        for pid in pids {
            guard let bsdInfo = Self.bsdInfo(for: pid) else { continue }

            let executablePath = Self.executablePath(for: pid)
            let rawName = Self.processName(for: pid) ?? executablePath.map {
                URL(fileURLWithPath: $0).lastPathComponent
            } ?? "PID \(pid)"
            let appMetadata = appsByPID[pid]

            let usage = Self.rusage(for: pid)
            let taskInfo = Self.taskInfo(for: pid)

            let cpuSeconds = usage.map {
                Double($0.ri_user_time + $0.ri_system_time) / 1_000_000_000
            } ?? 0
            let wallInterval = previousSamples[pid].map { now.timeIntervalSince($0.timestamp) } ?? 0
            let cpuPercent: Double
            if let previous = previousSamples[pid], wallInterval > 0.05 {
                let delta = max(0, cpuSeconds - previous.cpuSeconds)
                cpuPercent = delta / wallInterval * 100
            } else {
                cpuPercent = 0
            }
            newSamples[pid] = CPUSample(cpuSeconds: cpuSeconds, timestamp: now)

            let memoryBytes = usage.map(\.ri_phys_footprint)
                ?? UInt64(max(0, taskInfo?.pti_resident_size ?? 0))
            let threadCount = Int(taskInfo?.pti_threadnum ?? 0)

            // Match helpers to a top-level .app. The longest matching bundle
            // path wins, so nested helper bundles resolve to their host app.
            let hostBundlePath = executablePath.flatMap { path in
                appBundlePaths
                    .filter { path == $0 || path.hasPrefix($0 + "/") }
                    .max(by: { $0.count < $1.count })
            }

            let isRoot = appMetadata != nil
            let kind: ProcessKind
            if isRoot {
                kind = .application
            } else {
                kind = Self.classify(name: rawName, path: executablePath)
            }

            let startDate = Self.startDate(from: bsdInfo)
            let owner = Self.userName(uid: bsdInfo.pbi_uid) ?? NSUserName()

            processes.append(
                MonitoredProcess(
                    pid: pid,
                    parentPID: Int32(bitPattern: bsdInfo.pbi_ppid),
                    name: rawName,
                    displayName: isRoot ? appMetadata?.name : nil,
                    executablePath: executablePath,
                    appBundlePath: appMetadata?.bundlePath ?? hostBundlePath,
                    bundleIdentifier: appMetadata?.bundleIdentifier,
                    isApplicationRoot: isRoot,
                    kind: kind,
                    metrics: ResourceMetrics(
                        cpuPercent: cpuPercent,
                        memoryBytes: memoryBytes,
                        threadCount: threadCount
                    ),
                    startDate: startDate,
                    userName: owner
                )
            )
        }

        previousSamples = newSamples

        guard processes.contains(where: \.isApplicationRoot) else {
            throw ProcessDataError.noVisibleApplications
        }

        return ProcessSnapshot(
            processes: processes,
            timestamp: now,
            hiddenBackgroundProcessCount: 0, // Grouping reports excluded tasks precisely.
            hostMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            logicalCoreCount: ProcessInfo.processInfo.activeProcessorCount,
            sourceDescription: "This Mac"
        )
    }

    // MARK: - libproc helpers

    private static func allProcessIDs() -> [Int32] {
        let estimatedBytes = Int(proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0))
        guard estimatedBytes > 0 else { return [] }

        // Leave headroom: the process table can grow between the size query and
        // the read. The returned byte count tells us how many entries are valid.
        let capacity = max(16, estimatedBytes / MemoryLayout<pid_t>.size + 64)
        var pids = [pid_t](repeating: 0, count: capacity)
        let usedBytes = proc_listpids(
            UInt32(PROC_ALL_PIDS),
            0,
            &pids,
            Int32(capacity * MemoryLayout<pid_t>.size)
        )
        guard usedBytes > 0 else { return [] }

        let count = min(pids.count, Int(usedBytes) / MemoryLayout<pid_t>.size)
        return pids.prefix(count).filter { $0 > 0 }
    }

    private static func processName(for pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let result = proc_name(pid, &buffer, UInt32(buffer.count))
        guard result > 0 else { return nil }
        return String(cString: buffer)
    }

    private static func executablePath(for pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let result = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard result > 0 else { return nil }
        return String(cString: buffer)
    }

    private static func bsdInfo(for pid: Int32) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let result = proc_pidinfo(
            pid,
            PROC_PIDTBSDINFO,
            0,
            &info,
            Int32(MemoryLayout<proc_bsdinfo>.stride)
        )
        guard result == Int32(MemoryLayout<proc_bsdinfo>.stride) else { return nil }
        return info
    }

    private static func taskInfo(for pid: Int32) -> proc_taskinfo? {
        var info = proc_taskinfo()
        let result = proc_pidinfo(
            pid,
            PROC_PIDTASKINFO,
            0,
            &info,
            Int32(MemoryLayout<proc_taskinfo>.stride)
        )
        guard result == Int32(MemoryLayout<proc_taskinfo>.stride) else { return nil }
        return info
    }

    private static func rusage(for pid: Int32) -> rusage_info_v4? {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
                proc_pid_rusage(pid, RUSAGE_INFO_V4, rebound)
            }
        }
        guard result == 0 else { return nil }
        return info
    }

    private static func startDate(from info: proc_bsdinfo) -> Date? {
        let seconds = TimeInterval(info.pbi_start_tvsec)
        let microseconds = TimeInterval(info.pbi_start_tvusec) / 1_000_000
        guard seconds > 0 else { return nil }
        return Date(timeIntervalSince1970: seconds + microseconds)
    }

    private static func userName(uid: uid_t) -> String? {
        guard let passwordEntry = getpwuid(uid), let name = passwordEntry.pointee.pw_name else {
            return nil
        }
        return String(cString: name)
    }

    private static func classify(name: String, path: String?) -> ProcessKind {
        let haystack = (name + " " + (path ?? "")).lowercased()
        if haystack.contains("renderer") || haystack.contains("webcontent") || haystack.contains("gpu") {
            return .renderer
        }
        if haystack.contains("helper") || haystack.contains("agent") {
            return .helper
        }
        if haystack.contains("service") || haystack.contains("daemon") || haystack.contains("xpc") {
            return .service
        }
        return .helper
    }
}
