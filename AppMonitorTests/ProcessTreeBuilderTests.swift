import XCTest
@testable import AppMonitor

final class ProcessTreeBuilderTests: XCTestCase {
    private let builder = ProcessTreeBuilder()

    func testOnlyUserFacingApplicationsBecomeRootGroups() {
        let snapshot = MockScenario.makeSnapshot(jitter: false)
        let result = builder.build(from: snapshot.processes)

        XCTAssertEqual(result.groups.count, 11)
        XCTAssertTrue(result.groups.allSatisfy { $0.application.isApplicationRoot })
        XCTAssertFalse(result.groups.contains { $0.displayName == "MenuBarAgent" })
        XCTAssertFalse(result.groups.contains { $0.displayName == "launchd" })
        XCTAssertGreaterThanOrEqual(result.excludedProcessCount, 5)
    }

    func testEverySecretedProcessIsEitherIncludedOrReportedAsExcluded() {
        let snapshot = MockScenario.makeSnapshot(jitter: false)
        let result = builder.build(from: snapshot.processes)

        XCTAssertEqual(
            result.includedProcessCount + result.excludedProcessCount,
            snapshot.processes.count
        )
    }

    func testChromeHelpersAreGroupedBeneathChrome() {
        let snapshot = MockScenario.makeSnapshot(jitter: false)
        let result = builder.build(from: snapshot.processes)

        guard let chrome = result.groups.first(where: { $0.bundleIdentifier == "com.google.Chrome" }) else {
            return XCTFail("Expected a Google Chrome group")
        }

        XCTAssertEqual(chrome.processCount, 7)
        XCTAssertEqual(chrome.descendants.filter { $0.process.name.contains("Renderer") }.count, 3)
        XCTAssertTrue(chrome.descendants.contains { $0.process.name.contains("GPU") })
        XCTAssertTrue(chrome.descendants.contains { $0.process.name.contains("Network") })
        XCTAssertGreaterThan(chrome.metrics.cpuPercent, chrome.application.metrics.cpuPercent)
        XCTAssertGreaterThan(chrome.metrics.memoryBytes, chrome.application.metrics.memoryBytes)
    }

    func testAggregatedMetricsEqualTheSumOfTheTree() {
        let snapshot = MockScenario.makeSnapshot(jitter: false)
        let result = builder.build(from: snapshot.processes)

        for group in result.groups {
            let expectedCPU = group.allProcesses.reduce(0) { $0 + $1.metrics.cpuPercent }
            let expectedMemory = group.allProcesses.reduce(UInt64(0)) { $0 + $1.metrics.memoryBytes }
            let expectedThreads = group.allProcesses.reduce(0) { $0 + $1.metrics.threadCount }

            XCTAssertEqual(group.metrics.cpuPercent, expectedCPU, accuracy: 0.0001)
            XCTAssertEqual(group.metrics.memoryBytes, expectedMemory)
            XCTAssertEqual(group.metrics.threadCount, expectedThreads)
        }
    }

    func testNestedWorkerDepthIsPreserved() {
        let snapshot = MockScenario.makeSnapshot(jitter: false)
        let result = builder.build(from: snapshot.processes)

        guard let xcode = result.groups.first(where: { $0.bundleIdentifier == "com.apple.dt.Xcode" }) else {
            return XCTFail("Expected Xcode")
        }

        guard let compiler = xcode.descendants.first(where: { $0.process.name == "swift-frontend" }) else {
            return XCTFail("Expected swift-frontend")
        }

        XCTAssertEqual(compiler.depth, 1)
        XCTAssertEqual(compiler.process.parentPID, 3124)
    }

    func testOrphanedHelperInsideBundleIsAdopted() {
        let root = MonitoredProcess(
            pid: 900,
            parentPID: 1,
            name: "TestApp",
            executablePath: "/Applications/TestApp.app/Contents/MacOS/TestApp",
            appBundlePath: "/Applications/TestApp.app",
            bundleIdentifier: "com.example.TestApp",
            isApplicationRoot: true,
            kind: .application,
            metrics: ResourceMetrics(cpuPercent: 1, memoryBytes: 100, threadCount: 2)
        )

        // XPC services are often re-parented to launchd. Bundle containment is
        // the fallback signal that keeps them attached to the right app.
        let orphan = MonitoredProcess(
            pid: 901,
            parentPID: 1,
            name: "TestApp Helper",
            executablePath: "/Applications/TestApp.app/Contents/Frameworks/TestApp Helper.app/Contents/MacOS/TestApp Helper",
            appBundlePath: "/Applications/TestApp.app",
            kind: .helper,
            metrics: ResourceMetrics(cpuPercent: 2, memoryBytes: 200, threadCount: 4)
        )

        let unrelatedAgent = MonitoredProcess(
            pid: 902,
            parentPID: 1,
            name: "MenuBarAgent",
            isApplicationRoot: false,
            kind: .daemon,
            metrics: ResourceMetrics(cpuPercent: 9, memoryBytes: 900, threadCount: 1)
        )

        let result = builder.build(from: [orphan, unrelatedAgent, root])

        XCTAssertEqual(result.groups.count, 1)
        XCTAssertEqual(result.groups[0].processCount, 2)
        XCTAssertEqual(result.groups[0].descendants.first?.process.pid, 901)
        XCTAssertEqual(result.excludedProcessCount, 1)
    }

    func testDuplicatePIDsAreNotDoubleCounted() {
        let snapshot = MockScenario.makeSnapshot(jitter: false)
        let duplicated = snapshot.processes + snapshot.processes
        let result = builder.build(from: duplicated)

        XCTAssertEqual(result.includedProcessCount + result.excludedProcessCount, snapshot.processes.count)
    }
}
