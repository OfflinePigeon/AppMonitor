import Combine
import Foundation

/// Owns all state for the monitoring window. Views are intentionally dumb:
/// they render the sorted, filtered groups this class exposes and forward user
/// intent back through small methods.
@MainActor
final class AppMonitorViewModel: ObservableObject {
    // MARK: - Published state

    @Published private(set) var groups: [ApplicationGroup] = []
    @Published private(set) var hostMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    @Published private(set) var logicalCoreCount: Int = ProcessInfo.processInfo.activeProcessorCount
    @Published private(set) var hiddenBackgroundCount: Int = 0
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var favoriteBundleIDs: Set<String>

    @Published var activeFilter: SidebarFilter = .all
    @Published var sortKey: ProcessSortKey = .cpu {
        didSet {
            guard sortKey != oldValue else { return }
            reorderMainList()
        }
    }
    @Published var searchText = ""
    @Published var expandedGroupIDs: Set<ApplicationGroup.ID> = []

    // MARK: - Dependencies

    private let provider: ProcessDataProviding
    private let treeBuilder = ProcessTreeBuilder()
    private let persistsFavorites: Bool

    let refreshInterval: TimeInterval

    // MARK: - Private state

    private var monitorTask: Task<Void, Never>?
    private var historyByGroupID: [ApplicationGroup.ID: [Double]] = [:]
    private var stableGroupOrder: [ApplicationGroup.ID] = []
    private var hasEstablishedStableOrder = false
    private var didSeedInitialExpansion = false
    private var loadGeneration = 0
    private let historyCapacity = 30
    private static let favoritesDefaultsKey = "AppMonitor.favoriteBundleIdentifiers"

    // MARK: - Init

    init(
        provider: ProcessDataProviding = LiveProcessDataProvider(),
        initialSnapshot: ProcessSnapshot? = nil,
        favorites: Set<String>? = nil,
        persistsFavorites: Bool = true,
        refreshInterval: TimeInterval = 2.5,
        seedHistory: Bool = false
    ) {
        self.provider = provider
        self.persistsFavorites = persistsFavorites
        self.refreshInterval = refreshInterval

        if let favorites {
            self.favoriteBundleIDs = favorites
        } else if persistsFavorites,
                  let stored = UserDefaults.standard.stringArray(forKey: Self.favoritesDefaultsKey) {
            self.favoriteBundleIDs = Set(stored)
        } else {
            self.favoriteBundleIDs = []
        }

        if let initialSnapshot {
            apply(snapshot: initialSnapshot, seedPreviewHistory: seedHistory)
        }
    }

    // MARK: - Derived collections

    /// The only list the main view renders: filter → search → frozen order.
    ///
    /// The order is established once (highest CPU first on a normal launch) and
    /// then held steady across refreshes, so rows never jump while the user is
    /// reading them. Changing the sort control deliberately re-ranks once.
    var visibleGroups: [ApplicationGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = groups.filter { group in
            activeFilter.includes(group, isFavorite: isFavorite(group))
        }
        let searched = query.isEmpty ? filtered : filtered.filter { $0.matches(searchText: query) }
        return ordered(searched)
    }

    /// All running applications in live CPU order, independent of the frozen
    /// main list. Used by the inspector's continuously updating ranking.
    var liveCPUOrderedGroups: [ApplicationGroup] {
        groups.sorted(by: Self.cpuRanking)
    }

    var visibleProcessCount: Int {
        visibleGroups.reduce(0) { $0 + $1.processCount }
    }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var maxVisibleCPU: Double {
        max(visibleGroups.map(\.metrics.cpuPercent).max() ?? 0, 0.1)
    }

    var maxVisibleMemory: UInt64 {
        max(visibleGroups.map(\.metrics.memoryBytes).max() ?? 0, 1)
    }

    var activeFilterHeadline: String {
        activeFilter.headline
    }

    var backgroundProcessCount: Int {
        hiddenBackgroundCount
    }

    /// Sidebar counts always describe the full dataset, not the active search.
    func count(for filter: SidebarFilter) -> Int {
        groups.filter { filter.includes($0, isFavorite: isFavorite($0)) }.count
    }

    func group(withID id: ApplicationGroup.ID?) -> ApplicationGroup? {
        guard let id else { return nil }
        return groups.first { $0.id == id }
    }

    func isFavorite(_ group: ApplicationGroup) -> Bool {
        favoriteBundleIDs.contains(favoriteKey(for: group))
    }

    func history(for group: ApplicationGroup) -> [Double] {
        historyByGroupID[group.id] ?? []
    }

    // MARK: - User intent

    func toggleExpanded(_ group: ApplicationGroup) {
        if expandedGroupIDs.contains(group.id) {
            expandedGroupIDs.remove(group.id)
        } else {
            expandedGroupIDs.insert(group.id)
        }
    }

    func expand(_ group: ApplicationGroup) {
        expandedGroupIDs.insert(group.id)
    }

    func collapse(_ group: ApplicationGroup) {
        expandedGroupIDs.remove(group.id)
    }

    func toggleFavorite(_ group: ApplicationGroup) {
        let key = favoriteKey(for: group)
        if favoriteBundleIDs.contains(key) {
            favoriteBundleIDs.remove(key)
        } else {
            favoriteBundleIDs.insert(key)
        }
        persistFavoritesIfNeeded()
    }

    // MARK: - Monitoring lifecycle

    func startMonitoring() {
        guard monitorTask == nil else { return }

        monitorTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh()

            while !Task.isCancelled {
                let interval = self.refreshInterval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await self.refresh()
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    /// Fetches one snapshot. Also used by the Refresh button and ⌘R.
    func refresh() async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true

        defer {
            if generation == loadGeneration {
                isLoading = false
            }
        }

        do {
            let snapshot = try await provider.fetchSnapshot()
            guard generation == loadGeneration else { return }
            apply(snapshot: snapshot)
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration else { return }
            let suggestion = (error as? ProcessDataError)?.recoverySuggestion
            errorMessage = [error.localizedDescription, suggestion]
                .compactMap { $0 }
                .joined(separator: " ")
        }
    }

    // MARK: - Rendering pipeline

    private func apply(snapshot: ProcessSnapshot, seedPreviewHistory: Bool = false) {
        let result = treeBuilder.build(from: snapshot.processes)

        groups = result.groups
        hostMemoryBytes = snapshot.hostMemoryBytes
        logicalCoreCount = snapshot.logicalCoreCount
        hiddenBackgroundCount = snapshot.hiddenBackgroundProcessCount + result.excludedProcessCount
        lastUpdated = snapshot.timestamp

        // Drop expansion state for applications that are no longer running.
        let validIDs = Set(groups.map(\.id))
        expandedGroupIDs.formIntersection(validIDs)

        updateStableOrder()

        if seedPreviewHistory {
            seedHistoryForPreviews()
        }
        updateHistory()

        if !didSeedInitialExpansion,
           groups.contains(where: { $0.metrics.cpuPercent > 0 }),
           let busiest = groups.sorted(by: Self.cpuRanking)
               .first(where: { !$0.descendants.isEmpty }) {
            expandedGroupIDs.insert(busiest.id)
            didSeedInitialExpansion = true
        }
    }

    /// Establishes the main list's order on the first sample and then keeps it
    /// stable. Newly launched applications are appended rather than inserted,
    /// so existing rows never shift under the user's cursor.
    private func updateStableOrder() {
        let validIDs = Set(groups.map(\.id))

        guard hasEstablishedStableOrder else {
            stableGroupOrder = sorted(groups).map(\.id)
            if groups.contains(where: { $0.metrics.cpuPercent > 0 }) {
                hasEstablishedStableOrder = true
            }
            return
        }

        stableGroupOrder.removeAll { !validIDs.contains($0) }

        let knownIDs = Set(stableGroupOrder)
        let additions = sorted(groups.filter { !knownIDs.contains($0.id) })
        stableGroupOrder.append(contentsOf: additions.map(\.id))
    }

    private func ordered(_ input: [ApplicationGroup]) -> [ApplicationGroup] {
        guard !stableGroupOrder.isEmpty else { return sorted(input) }

        let positions = Dictionary(
            uniqueKeysWithValues: stableGroupOrder.enumerated().map { ($1, $0) }
        )
        return input.sorted {
            let left = positions[$0.id] ?? Int.max
            let right = positions[$1.id] ?? Int.max
            if left != right { return left < right }
            return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    /// Re-ranks the main list exactly once when the user changes the sort
    /// control, then leaves it frozen again.
    private func reorderMainList() {
        guard !groups.isEmpty else {
            stableGroupOrder = []
            hasEstablishedStableOrder = false
            return
        }
        stableGroupOrder = sorted(groups).map(\.id)
        hasEstablishedStableOrder = true
    }

    private func sorted(_ input: [ApplicationGroup]) -> [ApplicationGroup] {
        switch sortKey {
        case .cpu:
            return input.sorted(by: Self.cpuRanking)
        case .memory:
            return input.sorted {
                if $0.metrics.memoryBytes != $1.metrics.memoryBytes {
                    return $0.metrics.memoryBytes > $1.metrics.memoryBytes
                }
                if $0.metrics.cpuPercent != $1.metrics.cpuPercent {
                    return $0.metrics.cpuPercent > $1.metrics.cpuPercent
                }
                return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
        case .name:
            return input.sorted {
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
        }
    }

    private static func cpuRanking(
        _ lhs: ApplicationGroup,
        _ rhs: ApplicationGroup
    ) -> Bool {
        if lhs.metrics.cpuPercent != rhs.metrics.cpuPercent {
            return lhs.metrics.cpuPercent > rhs.metrics.cpuPercent
        }
        if lhs.metrics.memoryBytes != rhs.metrics.memoryBytes {
            return lhs.metrics.memoryBytes > rhs.metrics.memoryBytes
        }
        return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
    }

    private func updateHistory() {
        var updated: [ApplicationGroup.ID: [Double]] = [:]
        for group in groups {
            var samples = historyByGroupID[group.id] ?? []
            if samples.last != group.metrics.cpuPercent {
                samples.append(group.metrics.cpuPercent)
            }
            updated[group.id] = Array(samples.suffix(historyCapacity))
        }
        historyByGroupID = updated
    }

    /// Previews look more convincing with a populated graph. This generates a
    /// deterministic, gently varying backstory around each current value; it is
    /// only used when a preview/test passes `seedHistory: true`.
    private func seedHistoryForPreviews() {
        for group in groups {
            let current = max(group.metrics.cpuPercent, 0.1)
            let phase = Double(abs(group.application.pid) % 11) * 0.37
            let prior = (0..<24).map { index -> Double in
                let wave = sin(Double(index) * 0.48 + phase) * 0.22
                let drift = 0.9 + (Double(index) / 24.0) * 0.1
                return max(0, current * (1 + wave) * drift)
            }
            historyByGroupID[group.id] = prior + [current]
        }
    }

    // MARK: - Favorites persistence

    private func favoriteKey(for group: ApplicationGroup) -> String {
        group.bundleIdentifier ?? group.id
    }

    private func persistFavoritesIfNeeded() {
        guard persistsFavorites else { return }
        UserDefaults.standard.set(Array(favoriteBundleIDs), forKey: Self.favoritesDefaultsKey)
    }
}

extension AppMonitorViewModel {
    /// A ready-to-render view model used by `#Preview` blocks. It uses only the
    /// mock provider so no preview ever samples the live system. Never called
    /// by the shipping window.
    static func preview(
        filter: SidebarFilter = .all,
        sort: ProcessSortKey = .cpu,
        favorites: Set<String> = ["com.apple.dt.Xcode"]
    ) -> AppMonitorViewModel {
        let provider = MockProcessDataProvider(jitter: false)
        let viewModel = AppMonitorViewModel(
            provider: provider,
            initialSnapshot: MockScenario.makeSnapshot(jitter: false),
            favorites: favorites,
            persistsFavorites: false,
            seedHistory: true
        )
        viewModel.activeFilter = filter
        viewModel.sortKey = sort
        return viewModel
    }
}
