import AppKit
import SwiftUI

/// Three-pane shell: smart filters on the left, ordered application trees in the
/// middle, and a live detail inspector on the right.
struct ContentView: View {
    @ObservedObject var viewModel: AppMonitorViewModel
    @Binding var isInspectorPresented: Bool
    @State private var selection: ApplicationGroup.ID?

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 218, ideal: 238, max: 290)
        } detail: {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    MonitorListView(viewModel: viewModel, selection: $selection)
                        .navigationTitle("AppMonitor")
                        .searchable(
                            text: $viewModel.searchText,
                            placement: .toolbar,
                            prompt: "Search apps and processes"
                        )

                    if isInspectorPresented {
                        // SwiftUI's native `.inspector` enters an AppKit
                        // constraint update loop when this window is resized
                        // horizontally. A custom pane is stable at every width
                        // and matches the inspector's visual treatment.
                        Rectangle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: 0.7)
                            .accessibilityHidden(true)

                        ProcessDetailView(
                            viewModel: viewModel,
                            group: selectedGroup,
                            onSelect: { selection = $0 }
                        )
                        .frame(width: inspectorWidth(for: geometry.size.width))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .frame(minWidth: 1100, minHeight: 640)
        .toolbar { toolbarContent }
        .task {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
        .onChange(of: viewModel.visibleGroups.map(\.id), initial: true) { _, ids in
            if let selection, ids.contains(selection) {
                return
            }
            selection = ids.first
        }
    }

    private var selectedGroup: ApplicationGroup? {
        if let match = viewModel.visibleGroups.first(where: { $0.id == selection }) {
            return match
        }
        return viewModel.group(withID: selection)
    }

    /// Keep the application list readable when the window approaches its
    /// minimum width by giving the inspector a slightly narrower column.
    private func inspectorWidth(for detailWidth: CGFloat) -> CGFloat {
        detailWidth >= 960 ? 368 : 320
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .foregroundStyle(Color.red.opacity(0.82))
            }
            .help("Quit AppMonitor (⌘Q)")

            Button {
                Task { await viewModel.refresh() }
            } label: {
                ZStack {
                    Image(systemName: "arrow.clockwise")
                        .opacity(viewModel.isLoading ? 0 : 1)
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .frame(width: 16, height: 16)
            }
            .help("Refresh now (⌘R)")
            .disabled(viewModel.isLoading)

            Button {
                isInspectorPresented.toggle()
            } label: {
                Image(systemName: "sidebar.trailing")
                    .foregroundStyle(isInspectorPresented ? Color.accentColor : Color.primary)
            }
            .help(isInspectorPresented ? "Hide details (⌥⌘I)" : "Show details (⌥⌘I)")
        }
    }
}

#Preview("AppMonitor — Light") {
    let viewModel = AppMonitorViewModel.preview()
    ContentView(viewModel: viewModel, isInspectorPresented: .constant(true))
        .frame(width: 1_280, height: 820)
        .preferredColorScheme(.light)
}

#Preview("AppMonitor — Dark") {
    let viewModel = AppMonitorViewModel.preview()
    ContentView(viewModel: viewModel, isInspectorPresented: .constant(true))
        .frame(width: 1_280, height: 820)
        .preferredColorScheme(.dark)
}

#Preview("High Memory — Ranked") {
    let viewModel = AppMonitorViewModel.preview(filter: .highMemory, sort: .memory)
    ContentView(viewModel: viewModel, isInspectorPresented: .constant(false))
        .frame(width: 1_180, height: 760)
        .preferredColorScheme(.light)
}
