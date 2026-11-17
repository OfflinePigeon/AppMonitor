import XCTest
@testable import AppMonitor

final class AppMonitorViewModelTests: XCTestCase {
    @MainActor
    private func makeViewModel(
        filter: SidebarFilter = .all,
        favorites: Set<String> = []
    ) -> AppMonitorViewModel {
        let provider = MockProcessDataProvider(jitter: false)
        let viewModel = AppMonitorViewModel(
            provider: provider,
            initialSnapshot: MockScenario.makeSnapshot(jitter: false),
            favorites: favorites,
            persistsFavorites: false,
            refreshInterval: 60
        )
        viewModel.activeFilter = filter
        return viewModel
    }

    @MainActor
    func testDefaultRankingIsCPUDescending() {
        let viewModel = makeViewModel()
        let values = viewModel.visibleGroups.map(\.metrics.cpuPercent)

        XCTAssertEqual(values, values.sorted(by: >))
        XCTAssertEqual(viewModel.visibleGroups.first?.bundleIdentifier, "com.google.Chrome")
    }

    @MainActor
    func testMemorySortRanksHighestFootprintFirst() {
        let viewModel = makeViewModel()
        viewModel.sortKey = .memory
        let values = viewModel.visibleGroups.map(\.metrics.memoryBytes)

        XCTAssertEqual(values, values.sorted(by: >))
        XCTAssertEqual(viewModel.visibleGroups.first?.bundleIdentifier, "com.google.Chrome")
    }

    @MainActor
    func testNameSortIsAlphabetical() {
        let viewModel = makeViewModel()
        viewModel.sortKey = .name
        let names = viewModel.visibleGroups.map(\.displayName)

        XCTAssertEqual(
            names,
            names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        )
    }

    @MainActor
    func testSearchingAChildProcessKeepsItsParentGroup() {
        let viewModel = makeViewModel()
        viewModel.searchText = "SourceKitService"

        XCTAssertEqual(viewModel.visibleGroups.count, 1)
        XCTAssertEqual(viewModel.visibleGroups.first?.displayName, "Xcode")
        XCTAssertGreaterThan(
            viewModel.visibleGroups.first?.matchingDescendantCount(for: "SourceKitService") ?? 0,
            0
        )
    }

    @MainActor
    func testSearchingByPIDMatchesTheOwningApplication() {
        let viewModel = makeViewModel()
        guard let chrome = viewModel.groups.first(where: { $0.bundleIdentifier == "com.google.Chrome" }),
              let renderer = chrome.descendants.first else {
            return XCTFail("Expected a Chrome renderer")
        }

        viewModel.searchText = String(renderer.process.pid)

        XCTAssertTrue(viewModel.visibleGroups.contains { $0.id == chrome.id })
    }

    @MainActor
    func testHighCPUFilterOnlyContainsMatchingApplications() {
        let viewModel = makeViewModel(filter: .highCPU)

        XCTAssertFalse(viewModel.visibleGroups.isEmpty)
        XCTAssertTrue(
            viewModel.visibleGroups.allSatisfy {
                $0.metrics.cpuPercent >= SidebarFilter.highCPUThreshold
            }
        )
    }

    @MainActor
    func testHighMemoryFilterOnlyContainsMatchingApplications() {
        let viewModel = makeViewModel(filter: .highMemory)

        XCTAssertFalse(viewModel.visibleGroups.isEmpty)
        XCTAssertTrue(
            viewModel.visibleGroups.allSatisfy {
                $0.metrics.memoryBytes >= SidebarFilter.highMemoryThreshold
            }
        )
    }

    @MainActor
    func testFavoritesFilterReflectsToggledState() {
        let viewModel = makeViewModel()
        guard let chrome = viewModel.groups.first(where: { $0.bundleIdentifier == "com.google.Chrome" }) else {
            return XCTFail("Expected Google Chrome")
        }

        viewModel.toggleFavorite(chrome)
        XCTAssertTrue(viewModel.isFavorite(chrome))

        viewModel.activeFilter = .favorites
        XCTAssertEqual(viewModel.visibleGroups.map(\.id), [chrome.id])

        viewModel.toggleFavorite(chrome)
        XCTAssertTrue(viewModel.visibleGroups.isEmpty)
    }

    @MainActor
    func testInitialExpansionHighlightsTheBusiestApplicationWithChildren() {
        let viewModel = makeViewModel()
        let busiestID = viewModel.groups
            .filter { !$0.descendants.isEmpty }
            .max(by: { $0.metrics.cpuPercent < $1.metrics.cpuPercent })?.id

        XCTAssertEqual(viewModel.expandedGroupIDs, Set([busiestID].compactMap { $0 }))
    }

    @MainActor
    func testPreviewHistoryProvidesGraphSamples() {
        let viewModel = AppMonitorViewModel.preview()
        guard let first = viewModel.visibleGroups.first else {
            return XCTFail("Expected a preview group")
        }

        XCTAssertGreaterThan(viewModel.history(for: first).count, 2)
    }

    @MainActor
    func testBackgroundFilteredCountIncludesSnapshotAndUnassignedAgents() {
        let viewModel = makeViewModel()
        let snapshot = MockScenario.makeSnapshot(jitter: false)
        let result = ProcessTreeBuilder().build(from: snapshot.processes)

        XCTAssertEqual(
            viewModel.backgroundProcessCount,
            MockScenario.additionalHiddenBackgroundCount + result.excludedProcessCount
        )
    }

    @MainActor
    func testMainListOrderStaysFrozenWhileLiveRankingChanges() async {
        let initial = MockScenario.makeSnapshot(jitter: false)
        let changed = Self.snapshot(initial, boosting: "/Applications/Xcode.app")
        let provider = SequenceProcessDataProvider([changed])
        let viewModel = AppMonitorViewModel(
            provider: provider,
            initialSnapshot: initial,
            favorites: [],
            persistsFavorites: false,
            refreshInterval: 60
        )

        let frozenOrder = viewModel.visibleGroups.map(\.id)
        XCTAssertEqual(viewModel.visibleGroups.first?.bundleIdentifier, "com.google.Chrome")

        await viewModel.refresh()

        XCTAssertEqual(viewModel.visibleGroups.map(\.id), frozenOrder)
        XCTAssertEqual(viewModel.liveCPUOrderedGroups.first?.bundleIdentifier, "com.apple.dt.Xcode")
    }

    private static func snapshot(
        _ base: ProcessSnapshot,
        boosting bundlePathFragment: String
    ) -> ProcessSnapshot {
        let processes = base.processes.map { process in
            let cpu = process.appBundlePath?.contains(bundlePathFragment) == true ? 100.0 : 0.0
            return MonitoredProcess(
                pid: process.pid,
                parentPID: process.parentPID,
                name: process.name,
                displayName: process.displayName,
                executablePath: process.executablePath,
                appBundlePath: process.appBundlePath,
                bundleIdentifier: process.bundleIdentifier,
                isApplicationRoot: process.isApplicationRoot,
                kind: process.kind,
                metrics: ResourceMetrics(
                    cpuPercent: cpu,
                    memoryBytes: process.metrics.memoryBytes,
                    threadCount: process.metrics.threadCount,
                    diskBytesPerSecond: process.metrics.diskBytesPerSecond,
                    energyImpact: process.metrics.energyImpact
                ),
                startDate: process.startDate,
                userName: process.userName
            )
        }

        return ProcessSnapshot(
            processes: processes,
            timestamp: Date(),
            hiddenBackgroundProcessCount: base.hiddenBackgroundProcessCount,
            hostMemoryBytes: base.hostMemoryBytes,
            logicalCoreCount: base.logicalCoreCount,
            sourceDescription: base.sourceDescription
        )
    }
}

private actor SequenceProcessDataProvider: ProcessDataProviding {
    private var snapshots: [ProcessSnapshot]

    init(_ snapshots: [ProcessSnapshot]) {
        self.snapshots = snapshots
    }

    func fetchSnapshot() async throws -> ProcessSnapshot {
        guard !snapshots.isEmpty else {
            throw ProcessDataError.processEnumerationFailed
        }
        return snapshots.removeFirst()
    }
}
