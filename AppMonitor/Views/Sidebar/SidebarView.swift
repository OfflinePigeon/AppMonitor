import SwiftUI

/// Sidebar smart filters plus the live monitoring status footer.
struct SidebarView: View {
    @ObservedObject var viewModel: AppMonitorViewModel

    var body: some View {
        VStack(spacing: 0) {
            brandHeader

            List(selection: $viewModel.activeFilter) {
                Section {
                    ForEach(SidebarFilter.allCases) { filter in
                        SidebarFilterRow(
                            filter: filter,
                            count: viewModel.count(for: filter)
                        )
                        .tag(filter)
                    }
                } header: {
                    Text("Monitor")
                }
            }
            .listStyle(.sidebar)

            SidebarFooterView(viewModel: viewModel)
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 10) {
            AppMarkView(size: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("AppMonitor")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("Process monitor")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Text("1.0")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.055)))
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.35)
        }
    }
}

private struct SidebarFilterRow: View {
    let filter: SidebarFilter
    let count: Int

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: filter.systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MetricPalette.tint(for: filter))
                .frame(width: 18)

            Text(filter.title)
                .font(.system(size: 12.5, weight: .medium))

            Spacer(minLength: 4)

            Text("\(count)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background(Capsule().fill(Color.primary.opacity(0.065)))
        }
        .help(filterHelp)
    }

    private var filterHelp: String {
        switch filter {
        case .all:
            return "Every regular, user-facing application and its process tree."
        case .highCPU:
            return "Applications using at least 10% of one CPU core."
        case .highMemory:
            return "Applications with a physical footprint of 1 GB or more."
        case .favorites:
            return "Applications you have starred."
        }
    }
}

private struct SidebarFooterView: View {
    @ObservedObject var viewModel: AppMonitorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().opacity(0.35)

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)

                Text("Auto-refresh · \(cadenceLabel)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 2)

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh now")
                .disabled(viewModel.isLoading)
            }

            HStack(spacing: 6) {
                Label("Live System", systemImage: "dot.radiowaves.left.and.right")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 4)

                if let lastUpdated = viewModel.lastUpdated {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 8))
                            Text(relativeUpdateLabel(for: lastUpdated, now: context.date))
                                .lineLimit(1)
                        }
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                    }
                    .help("Last refreshed")
                }
            }

            HStack(spacing: 5) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 9.5))
                Text("\(viewModel.backgroundProcessCount) background tasks filtered")
                    .font(.system(size: 9.5))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.tertiary)
            .help("Standalone daemons and unassigned launch agents stay out of the list. Their count is shown here so nothing disappears silently.")
        }
        .padding(.horizontal, 12)
        .padding(.top, 7)
        .padding(.bottom, 10)
    }

    private var cadenceLabel: String {
        if viewModel.refreshInterval == floor(viewModel.refreshInterval) {
            return "\(Int(viewModel.refreshInterval))s"
        }
        return String(format: "%.1fs", viewModel.refreshInterval)
    }

    private func relativeUpdateLabel(for date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date).rounded()))
        if seconds < 3 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
    }
}

#Preview("Sidebar") {
    SidebarView(viewModel: AppMonitorViewModel.preview())
        .frame(width: 239, height: 780)
}
