import AppKit
import SwiftUI

/// Inspector shown alongside the list. It expands the selected application into
/// its aggregate resource story and a continuously updating ranking of every
/// running application, so live movement stays out of the frozen main list.
struct ProcessDetailView: View {
    @ObservedObject var viewModel: AppMonitorViewModel
    let group: ApplicationGroup?
    var onSelect: (ApplicationGroup.ID) -> Void = { _ in }

    @State private var didCopySummary = false

    var body: some View {
        Group {
            if let group {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header(for: group)
                        metrics(for: group)
                        activity(for: group)
                        liveApplications(selectedID: group.id)
                        details(for: group)
                        footer(for: group)
                    }
                    .padding(16)
                }
                .scrollIndicators(.automatic)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    // MARK: - Header

    private func header(for group: ApplicationGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                AppIconView(process: group.application, size: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(group.displayName)
                        .font(.system(size: 17.5, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(group.bundleIdentifier ?? group.application.executablePath ?? "No bundle identifier")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    HStack(spacing: 6) {
                        StatusPill(title: "Running", color: .green)
                        Text("PID \(group.application.pid)")
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 1)
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                Button {
                    viewModel.toggleFavorite(group)
                } label: {
                    Image(systemName: viewModel.isFavorite(group) ? "star.fill" : "star")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(
                            viewModel.isFavorite(group)
                                ? MetricPalette.favorite
                                : Color.primary.opacity(0.58)
                        )
                        .frame(width: 26, height: 26)
                        .background(
                            Circle().fill(
                                viewModel.isFavorite(group)
                                    ? MetricPalette.favorite.opacity(0.14)
                                    : Color.primary.opacity(0.055)
                            )
                        )
                        .overlay(
                            Circle().strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(viewModel.isFavorite(group) ? "Remove from Favorites" : "Add to Favorites")
            }

            HStack(spacing: 7) {
                Button {
                    revealInFinder(group)
                } label: {
                    Label("Reveal", systemImage: "folder")
                }
                .help("Reveal the application in Finder")
                .disabled(revealPath(for: group) == nil)

                Button {
                    copySummary(for: group)
                } label: {
                    Label(didCopySummary ? "Copied" : "Copy", systemImage: didCopySummary ? "checkmark" : "doc.on.doc")
                }
                .help("Copy a process-tree summary to the clipboard")

                Spacer(minLength: 0)
            }
            .buttonStyle(InspectorActionButtonStyle())
        }
    }

    // MARK: - Metrics

    private func metrics(for group: ApplicationGroup) -> some View {
        HStack(spacing: 9) {
            DetailMetricCard(
                title: "CPU",
                systemImage: "cpu",
                value: MetricFormatter.cpu(group.metrics.cpuPercent),
                detail: "\(MetricFormatter.processCount(group.processCount)) · \(MetricFormatter.threadCount(group.threadCount))",
                progress: min(group.metrics.cpuPercent / 100, 1),
                tint: MetricPalette.cpuTint(for: group.metrics.cpuPercent)
            )

            DetailMetricCard(
                title: "Memory",
                systemImage: "memorychip",
                value: MetricFormatter.memory(group.metrics.memoryBytes),
                detail: "\(MetricFormatter.memoryShare(group.metrics.memoryBytes, hostMemory: viewModel.hostMemoryBytes)) of \(MetricFormatter.hostedMemory(viewModel.hostMemoryBytes))",
                progress: viewModel.hostMemoryBytes > 0
                    ? Double(group.metrics.memoryBytes) / Double(viewModel.hostMemoryBytes)
                    : 0,
                tint: MetricPalette.memoryTint(for: group.metrics.memoryBytes)
            )
        }
    }

    // MARK: - Activity

    private func activity(for group: ApplicationGroup) -> some View {
        let history = viewModel.history(for: group)

        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("CPU Activity", systemImage: "chart.xyaxis.line")
                    .font(.system(size: 11.5, weight: .semibold))
                Spacer()
                Text(history.count > 1 ? "\(history.count) samples" : "Live samples")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            SparklineView(
                values: history,
                tint: MetricPalette.cpuTint(for: group.metrics.cpuPercent),
                height: 48
            )

            if history.count > 1 {
                HStack {
                    Text("Peak \(MetricFormatter.cpu(history.max() ?? 0))")
                    Spacer()
                    Text("Now \(MetricFormatter.cpu(group.metrics.cpuPercent))")
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        }
        .padding(11)
        .cardSurface()
    }

    // MARK: - Live application ranking

    private func liveApplications(selectedID: ApplicationGroup.ID) -> some View {
        let applications = viewModel.liveCPUOrderedGroups
        let peakCPU = max(applications.map(\.metrics.cpuPercent).max() ?? 0, 0.1)

        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Live Applications", systemImage: "dot.radiowaves.left.and.right")
                    .font(.system(size: 11.5, weight: .semibold))
                Spacer()
                Text("CPU order")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 0) {
                ForEach(Array(applications.enumerated()), id: \.element.id) { index, application in
                    Button {
                        onSelect(application.id)
                    } label: {
                        LiveApplicationRow(
                            rank: index + 1,
                            group: application,
                            peakCPU: peakCPU,
                            isSelected: application.id == selectedID
                        )
                    }
                    .buttonStyle(.plain)

                    if index < applications.count - 1 {
                        Rectangle()
                            .fill(Color.primary.opacity(0.05))
                            .frame(height: 0.5)
                            .padding(.leading, 38)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.22), value: applications.map(\.id))
        }
        .padding(11)
        .cardSurface()
    }

    // MARK: - Details

    private func details(for group: ApplicationGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Application Details", systemImage: "info.circle")
                .font(.system(size: 11.5, weight: .semibold))
                .padding(.bottom, 2)

            DetailInfoRow(label: "Bundle ID", value: group.bundleIdentifier ?? "Unavailable", isMonospaced: true)
            detailDivider
            DetailInfoRow(label: "Process ID", value: "\(group.application.pid)", isMonospaced: true)
            detailDivider
            DetailInfoRow(label: "Parent PID", value: "\(group.application.parentPID)", isMonospaced: true)
            detailDivider
            DetailInfoRow(label: "Launched", value: MetricFormatter.started(group.application.startDate))
            detailDivider
            DetailInfoRow(label: "User", value: group.application.userName)
            detailDivider
            DetailInfoRow(label: "Executable", value: group.application.executablePath ?? "Unavailable", isMonospaced: true, lineLimit: 3)
        }
        .padding(11)
        .cardSurface()
    }

    private var detailDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.05))
            .frame(height: 0.5)
            .padding(.leading, 74)
    }

    private func footer(for group: ApplicationGroup) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("Sampled from this Mac through libproc.", systemImage: "dot.radiowaves.left.and.right")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)

            HStack(spacing: 4) {
                Text("\(group.processCount) processes")
                Text("·")
                Text("\(viewModel.logicalCoreCount) logical cores")
            }
            .font(.system(size: 9))
            .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 4)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 11) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 25, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No Application Selected")
                .font(.system(size: 13, weight: .semibold))
            Text("Select an application to inspect its process tree, resource usage, and metadata.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 230)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions & helpers

    private func revealPath(for group: ApplicationGroup) -> String? {
        [group.application.executablePath, group.application.appBundlePath]
            .compactMap { $0 }
            .first { FileManager.default.fileExists(atPath: $0) }
    }

    private func revealInFinder(_ group: ApplicationGroup) {
        guard let path = revealPath(for: group) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func copySummary(for group: ApplicationGroup) {
        let summary = """
        \(group.displayName) — \(MetricFormatter.processCount(group.processCount))
        CPU \(MetricFormatter.cpu(group.metrics.cpuPercent)) · Memory \(MetricFormatter.memory(group.metrics.memoryBytes)) · \(MetricFormatter.threadCount(group.threadCount))
        Bundle: \(group.bundleIdentifier ?? "Unavailable")

        \(group.allEntries.map { entry in
            let indent = String(repeating: "    ", count: entry.depth)
            return "\(indent)\(entry.process.displayTitle)  PID \(entry.process.pid)  CPU \(MetricFormatter.cpu(entry.process.metrics.cpuPercent))  Mem \(MetricFormatter.memory(entry.process.metrics.memoryBytes))"
        }.joined(separator: "\n"))
        """

        Clipboard.copy(summary)
        didCopySummary = true
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            didCopySummary = false
        }
    }

}

// MARK: - Supporting views

private struct InspectorActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.primary.opacity(configuration.isPressed ? 0.65 : 0.82))
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                Capsule().fill(Color.primary.opacity(configuration.isPressed ? 0.11 : 0.055))
            )
            .overlay(
                Capsule().strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
            )
            .contentShape(Capsule())
    }
}

private struct DetailMetricCard: View {
    let title: String
    let systemImage: String
    let value: String
    let detail: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
                Text(title.uppercased())
                    .font(.system(size: 8.5, weight: .bold))
                    .tracking(0.7)
            }
            .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            ResourceBar(progress: progress, tint: tint, height: 3.5)

            Text(detail)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.065))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(0.14), lineWidth: 0.7)
        )
    }
}

private struct LiveApplicationRow: View {
    let rank: Int
    let group: ApplicationGroup
    let peakCPU: Double
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 7) {
            Text("\(rank)")
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.7))
                .frame(width: 15, alignment: .trailing)

            AppIconView(process: group.application, size: 16)

            Text(group.displayName)
                .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text(MetricFormatter.cpu(group.metrics.cpuPercent))
                    .font(.system(size: 9.5, weight: .medium))
                    .monospacedDigit()

                ResourceBar(
                    progress: group.metrics.cpuPercent / peakCPU,
                    tint: MetricPalette.cpuTint(for: group.metrics.cpuPercent),
                    height: 2
                )
                .frame(width: 36)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .help("\(group.displayName) · \(MetricFormatter.cpu(group.metrics.cpuPercent)) CPU · \(MetricFormatter.memory(group.metrics.memoryBytes)) memory")
    }
}

private struct DetailInfoRow: View {
    let label: String
    let value: String
    var isMonospaced = false
    var lineLimit = 1

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 66, alignment: .leading)

            Text(value)
                .font(.system(size: 9.5, design: isMonospaced ? .monospaced : .default))
                .foregroundStyle(.primary)
                .lineLimit(lineLimit)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

#Preview("Inspector — Expanded App") {
    let viewModel = AppMonitorViewModel.preview()
    ProcessDetailView(viewModel: viewModel, group: viewModel.visibleGroups.first)
        .frame(width: 368, height: 820)
        .preferredColorScheme(.light)
}

#Preview("Inspector — Dark") {
    let viewModel = AppMonitorViewModel.preview()
    ProcessDetailView(viewModel: viewModel, group: viewModel.visibleGroups.first)
        .frame(width: 368, height: 820)
        .preferredColorScheme(.dark)
}
