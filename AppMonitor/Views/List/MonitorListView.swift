import SwiftUI

/// Header, column controls, and the ordered hierarchical application list.
struct MonitorListView: View {
    @ObservedObject var viewModel: AppMonitorViewModel
    @Binding var selection: ApplicationGroup.ID?

    var body: some View {
        VStack(spacing: 0) {
            header
            if let errorMessage = viewModel.errorMessage {
                errorBanner(message: errorMessage)
            }
            content
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(viewModel.activeFilterHeadline)
                        .font(.system(size: 23, weight: .bold))
                        .lineLimit(1)

                    liveBadge
                }

                subtitleLabel
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text("ORDER BY")
                    .font(.system(size: 8.5, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)

                Picker("Order by", selection: $viewModel.sortKey) {
                    ForEach(ProcessSortKey.allCases) { key in
                        Text(key.title).tag(key)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 208)
                .help(viewModel.sortKey.accessibilityDescription)
            }
        }
        .padding(.horizontal, 21)
        .padding(.top, 17)
        .padding(.bottom, 13)
    }

    private var liveBadge: some View {
        HStack(spacing: 3.5) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 8, weight: .bold))
            Text("LIVE")
                .font(.system(size: 8.5, weight: .bold))
                .tracking(0.55)
        }
        .foregroundStyle(Color.green)
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(Capsule().fill(Color.green.opacity(0.12)))
        .help("Live process data sampled from this Mac through libproc")
    }

    /// Drop the ranking description rather than truncating the counts when the
    /// list column is narrow.
    private var subtitleLabel: some View {
        ViewThatFits(in: .horizontal) {
            subtitleText(subtitle)
            subtitleText(compactSubtitle)
        }
        .foregroundStyle(.secondary)
    }

    private func subtitleText(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 11.5, weight: .regular))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var subtitle: String {
        let appCount = viewModel.visibleGroups.count
        let apps = appCount == 1 ? "application" : "applications"
        let processes = viewModel.visibleProcessCount == 1 ? "process" : "processes"
        if viewModel.isSearching {
            return "\(appCount) matching \(apps) · \(viewModel.visibleProcessCount) \(processes) across their trees"
        }
        return "\(appCount) \(apps) · \(viewModel.visibleProcessCount) \(processes) · \(viewModel.sortKey.title.lowercased()) order fixed"
    }

    private var compactSubtitle: String {
        let appCount = viewModel.visibleGroups.count
        let apps = appCount == 1 ? "application" : "applications"
        let processes = viewModel.visibleProcessCount == 1 ? "process" : "processes"
        let suffix = viewModel.isSearching ? " matching" : ""
        return "\(appCount)\(suffix) \(apps) · \(viewModel.visibleProcessCount) \(processes)"
    }

    private func errorBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)
                .padding(.top, 1)

            Text(message)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 6)

            Button("Retry") {
                Task { await viewModel.refresh() }
            }
            .controlSize(.mini)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.orange.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.18), lineWidth: 0.7)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 7)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.groups.isEmpty, viewModel.isLoading {
            loadingState
        } else if viewModel.visibleGroups.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                ProcessColumnHeader(sortKey: $viewModel.sortKey)

                Rectangle()
                    .fill(Color.primary.opacity(0.07))
                    .frame(height: 0.7)
                    .padding(.horizontal, 16)

                List {
                    ForEach(viewModel.visibleGroups) { group in
                        ApplicationGroupRow(
                            group: group,
                            isSelected: selection == group.id,
                            isExpanded: viewModel.expandedGroupIDs.contains(group.id),
                            isFavorite: viewModel.isFavorite(group),
                            isSearching: viewModel.isSearching,
                            matchingProcessCount: viewModel.isSearching
                                ? group.matchingDescendantCount(for: viewModel.searchText)
                                : 0,
                            maxCPU: viewModel.maxVisibleCPU,
                            maxMemory: viewModel.maxVisibleMemory,
                            onSelect: { selection = group.id },
                            onToggleExpansion: { viewModel.toggleExpanded(group) },
                            onToggleFavorite: { viewModel.toggleFavorite(group) }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("Reading the process table…")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Grouping helpers under their parent applications.")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.isSearching {
            ContentUnavailableView.search(text: viewModel.searchText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.errorMessage != nil, viewModel.groups.isEmpty {
            ContentUnavailableView {
                Label("No Process Data", systemImage: "exclamationmark.triangle")
            } description: {
                Text("AppMonitor could not read process information from this Mac.")
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.refresh() }
                }
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView {
                Label(viewModel.activeFilter.emptyTitle, systemImage: viewModel.activeFilter.systemImage)
            } description: {
                Text(viewModel.activeFilter.emptyDescription)
            } actions: {
                if viewModel.activeFilter == .favorites {
                    Button("Browse All Applications") {
                        viewModel.activeFilter = .all
                    }
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Clickable table header. Each metric column doubles as a sort control so the
/// model is discoverable without hunting through a menu.
private struct ProcessColumnHeader: View {
    @Binding var sortKey: ProcessSortKey

    var body: some View {
        HStack(spacing: ProcessListLayout.columnSpacing) {
            SortHeaderButton(
                title: "Application",
                key: .name,
                sortKey: $sortKey,
                width: nil,
                isTrailing: false
            )

            SortHeaderButton(
                title: "CPU",
                key: .cpu,
                sortKey: $sortKey,
                width: ProcessListLayout.cpuColumnWidth,
                isTrailing: true
            )

            SortHeaderButton(
                title: "Memory",
                key: .memory,
                sortKey: $sortKey,
                width: ProcessListLayout.memoryColumnWidth,
                isTrailing: true
            )
        }
        .padding(.leading, 26)
        .padding(.trailing, ProcessListLayout.headerTrailingPadding)
        .frame(height: 27)
    }
}

private struct SortHeaderButton: View {
    let title: String
    let key: ProcessSortKey
    @Binding var sortKey: ProcessSortKey
    let width: CGFloat?
    let isTrailing: Bool

    private var alignment: Alignment {
        isTrailing ? .trailing : .leading
    }

    var body: some View {
        Button {
            sortKey = key
        } label: {
            HStack(spacing: 3) {
                if isTrailing {
                    Spacer(minLength: 0)
                }

                Text(title.uppercased())
                    .font(.system(size: 8.5, weight: .bold))
                    .tracking(0.75)

                if sortKey == key {
                    Image(systemName: key == .name ? "arrow.up" : "arrow.down")
                        .font(.system(size: 7.5, weight: .bold))
                }

                if !isTrailing {
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(sortKey == key ? Color.primary : Color.secondary)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Sort by \(title.lowercased())")
    }
}

#Preview("Application List") {
    let viewModel = AppMonitorViewModel.preview()
    MonitorListView(viewModel: viewModel, selection: .constant(viewModel.visibleGroups.first?.id))
        .frame(width: 900, height: 720)
}
