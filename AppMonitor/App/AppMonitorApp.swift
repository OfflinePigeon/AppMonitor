import SwiftUI

@main
struct AppMonitorApp: App {
    @StateObject private var viewModel = AppMonitorViewModel()
    @State private var isInspectorPresented = true

    init() {
        #if DEBUG
        SnapshotSupport.installIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup("AppMonitor") {
            ContentView(
                viewModel: viewModel,
                isInspectorPresented: $isInspectorPresented
            )
            .frame(minWidth: 1100, minHeight: 640)
        }
        .defaultSize(width: 1_270, height: 820)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Monitor") {
                Button("Refresh Now") {
                    Task { await viewModel.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(viewModel.isLoading)

                Picker("Order Applications By", selection: $viewModel.sortKey) {
                    ForEach(ProcessSortKey.allCases) { key in
                        Text(key.title).tag(key)
                    }
                }

                Button(isInspectorPresented ? "Hide Details" : "Show Details") {
                    isInspectorPresented.toggle()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
            }
        }
    }
}
