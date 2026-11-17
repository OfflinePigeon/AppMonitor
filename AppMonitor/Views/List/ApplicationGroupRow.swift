import AppKit
import SwiftUI

/// One application card: a selectable parent row plus, when expanded, every
/// helper, renderer, and nested worker in its process tree.
struct ApplicationGroupRow: View {
    let group: ApplicationGroup
    let isSelected: Bool
    let isExpanded: Bool
    let isFavorite: Bool
    let isSearching: Bool
    let matchingProcessCount: Int
    let maxCPU: Double
    let maxMemory: UInt64

    let onSelect: () -> Void
    let onToggleExpansion: () -> Void
    let onToggleFavorite: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            parentRow

            if isExpanded, !group.descendants.isEmpty {
                Rectangle()
                    .fill(Color.primary.opacity(0.055))
                    .frame(height: 0.6)
                    .padding(.leading, 42)

                VStack(spacing: 0) {
                    ForEach(Array(group.descendants.enumerated()), id: \.element.id) { _, entry in
                        ChildProcessRow(
                            entry: entry,
                            groupCPU: group.metrics.cpuPercent,
                            groupMemory: group.metrics.memoryBytes
                        )
                    }
                }
                .padding(.bottom, 4)
                .background(Color.primary.opacity(colorScheme == .dark ? 0.025 : 0.014))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(isSelected ? 0.065 : 0))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(isHovering && !isSelected ? 0.022 : 0))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.58) : Color.primary.opacity(0.07),
                    lineWidth: isSelected ? 1.2 : 0.7
                )
        )
        .overlay(alignment: .leading) {
            if isSelected {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.accentColor)
                    .frame(width: 3, height: 22)
                    .padding(.leading, 4)
                    .transition(.opacity)
            }
        }
        .shadow(color: Color.black.opacity(isSelected ? 0.065 : 0.04), radius: 3, x: 0, y: 1)
        .padding(.horizontal, ProcessListLayout.outerHorizontalPadding)
        .padding(.vertical, 4)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            onSelect()
        }
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.24), value: isExpanded)
        .animation(.easeOut(duration: 0.14), value: isSelected)
        .contextMenu { contextMenu }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(group.displayName), \(group.processCount) processes, \(MetricFormatter.cpu(group.metrics.cpuPercent)) CPU, \(MetricFormatter.memory(group.metrics.memoryBytes)) memory")
    }

    // MARK: - Parent row

    private var parentRow: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.snappy(duration: 0.24)) {
                    onToggleExpansion()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(group.descendants.isEmpty ? Color.clear : Color.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 16, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(group.descendants.isEmpty)
            .help(isExpanded ? "Hide helper processes" : "Show helper processes")
            .accessibilityLabel(isExpanded ? "Collapse \(group.displayName)" : "Expand \(group.displayName)")

            AppIconView(process: group.application, size: 28)

            VStack(alignment: .leading, spacing: 2.5) {
                HStack(spacing: 5) {
                    Text(group.displayName)
                        .font(.system(size: 13.5, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(MetricPalette.favorite)
                            .accessibilityLabel("Favorite")
                    }
                }

                subtitleLine
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(spacing: ProcessListLayout.columnSpacing) {
                MetricValueColumn(
                    value: MetricFormatter.cpu(group.metrics.cpuPercent),
                    progress: group.metrics.cpuPercent / maxCPU,
                    tint: MetricPalette.cpuTint(for: group.metrics.cpuPercent),
                    width: ProcessListLayout.cpuColumnWidth,
                    isProminent: true
                )

                MetricValueColumn(
                    value: MetricFormatter.memory(group.metrics.memoryBytes),
                    progress: Double(group.metrics.memoryBytes) / Double(maxMemory),
                    tint: MetricPalette.memoryTint(for: group.metrics.memoryBytes),
                    width: ProcessListLayout.memoryColumnWidth,
                    isProminent: true
                )
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, ProcessListLayout.cardTrailingPadding)
        .padding(.vertical, 9)
        .frame(minHeight: 55)
        .contentShape(Rectangle())
    }

    private var subtitleLine: some View {
        HStack(spacing: 5) {
            Text("PID \(group.application.pid)")
                .monospacedDigit()
            Text("·")
                .foregroundStyle(.tertiary)
            Text(MetricFormatter.processCount(group.processCount))
            Text("·")
                .foregroundStyle(.tertiary)
            Text(MetricFormatter.threadCount(group.threadCount))

            if isSearching, matchingProcessCount > 0 {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("\(matchingProcessCount) \(matchingProcessCount == 1 ? "match" : "matches")")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .font(.system(size: 10.5, weight: .regular))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    // MARK: - Context menu

    @ViewBuilder
    private var contextMenu: some View {
        Button {
            onToggleFavorite()
        } label: {
            Label(
                isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: isFavorite ? "star.slash" : "star"
            )
        }

        if let path = revealPath {
            Divider()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
        }

        Divider()

        Button {
            Clipboard.copy(copySummary)
        } label: {
            Label("Copy Process Summary", systemImage: "doc.on.doc")
        }

        Button {
            Clipboard.copy("\(group.application.pid)")
        } label: {
            Label("Copy PID", systemImage: "number")
        }
    }

    private var revealPath: String? {
        let candidates = [group.application.executablePath, group.application.appBundlePath]
        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0) }
    }

    private var copySummary: String {
        let header = "\(group.displayName) — \(group.processCount) processes"
        let totals = "CPU \(MetricFormatter.cpu(group.metrics.cpuPercent)) · Memory \(MetricFormatter.memory(group.metrics.memoryBytes)) · \(MetricFormatter.threadCount(group.threadCount))"
        let rows = group.allEntries.map { entry in
            let marker = entry.depth == 0 ? "  " : "  " + String(repeating: "    ", count: entry.depth)
            return "\(marker)\(entry.process.displayTitle) — PID \(entry.process.pid) — CPU \(MetricFormatter.cpu(entry.process.metrics.cpuPercent)) — \(MetricFormatter.memory(entry.process.metrics.memoryBytes))"
        }
        return ([header, totals, ""] + rows).joined(separator: "\n")
    }
}

/// A two-line right-aligned metric with a comparison bar.
private struct MetricValueColumn: View {
    let value: String
    let progress: Double
    let tint: Color
    let width: CGFloat
    let isProminent: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(value)
                .font(.system(size: isProminent ? 11.5 : 10.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            ResourceBar(
                progress: progress,
                tint: tint,
                height: isProminent ? 2.8 : 2.2
            )
            .frame(width: width - 8)
        }
        .frame(width: width, alignment: .trailing)
    }
}

/// Indented child process row. The PID is always visible; CPU and memory are
/// shown for the individual process, not the parent aggregate.
private struct ChildProcessRow: View {
    let entry: GroupedProcess
    let groupCPU: Double
    let groupMemory: UInt64

    @State private var isHovering = false

    private var process: MonitoredProcess { entry.process }

    var body: some View {
        HStack(spacing: ProcessListLayout.columnSpacing) {
            HStack(spacing: 8) {
                Color.clear
                    .frame(width: 28 + CGFloat(entry.depth) * 16, height: 1)

                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 10)

                ProcessKindIcon(kind: process.kind, size: 14)

                Text(process.displayTitle)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text("PID \(process.pid)")
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                    .fixedSize()

                if entry.depth > 0 {
                    Text("NESTED")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().strokeBorder(Color.primary.opacity(0.09), lineWidth: 0.5))
                        .fixedSize()
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(spacing: ProcessListLayout.columnSpacing) {
                MetricValueColumn(
                    value: MetricFormatter.cpu(process.metrics.cpuPercent),
                    progress: process.metrics.cpuPercent / max(groupCPU, 0.1),
                    tint: MetricPalette.cpuTint(for: process.metrics.cpuPercent),
                    width: ProcessListLayout.cpuColumnWidth,
                    isProminent: false
                )

                MetricValueColumn(
                    value: MetricFormatter.memory(process.metrics.memoryBytes),
                    progress: Double(process.metrics.memoryBytes) / Double(max(groupMemory, 1)),
                    tint: MetricPalette.memoryTint(for: process.metrics.memoryBytes),
                    width: ProcessListLayout.memoryColumnWidth,
                    isProminent: false
                )
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, ProcessListLayout.cardTrailingPadding)
        .frame(height: 32)
        .background(Color.primary.opacity(isHovering ? 0.032 : 0))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .help("\(process.displayTitle) · PID \(process.pid) · \(process.kind.title) · \(MetricFormatter.threadCount(process.metrics.threadCount))")
    }
}

#Preview("Application Tree — Expanded") {
    let viewModel = AppMonitorViewModel.preview()
    let group = viewModel.visibleGroups[0]

    ScrollView {
        VStack(spacing: 0) {
            ApplicationGroupRow(
                group: group,
                isSelected: true,
                isExpanded: true,
                isFavorite: false,
                isSearching: false,
                matchingProcessCount: 0,
                maxCPU: viewModel.maxVisibleCPU,
                maxMemory: viewModel.maxVisibleMemory,
                onSelect: {},
                onToggleExpansion: {},
                onToggleFavorite: {}
            )

            if viewModel.visibleGroups.count > 1 {
                ApplicationGroupRow(
                    group: viewModel.visibleGroups[1],
                    isSelected: false,
                    isExpanded: false,
                    isFavorite: true,
                    isSearching: false,
                    matchingProcessCount: 0,
                    maxCPU: viewModel.maxVisibleCPU,
                    maxMemory: viewModel.maxVisibleMemory,
                    onSelect: {},
                    onToggleExpansion: {},
                    onToggleFavorite: {}
                )
            }
        }
    }
    .background(Color(nsColor: .underPageBackgroundColor))
    .frame(width: 860, height: 560)
}
