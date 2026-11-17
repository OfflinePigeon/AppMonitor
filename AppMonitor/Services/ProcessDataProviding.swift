import Foundation

/// The single seam between the UI and the operating system.
///
/// `LiveProcessDataProvider` is the shipping implementation. The mock provider
/// conforms to the same protocol so previews and tests can exercise every view
/// without touching libproc. See README.md and `LiveProcessDataProvider.swift`
/// for the production migration guide.
protocol ProcessDataProviding: Sendable {
    func fetchSnapshot() async throws -> ProcessSnapshot
}

enum ProcessDataError: LocalizedError {
    case processEnumerationFailed
    case noVisibleApplications

    var errorDescription: String? {
        switch self {
        case .processEnumerationFailed:
            return "The process table could not be read."
        case .noVisibleApplications:
            return "No user-facing applications were found."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .processEnumerationFailed:
            return "Check that AppMonitor is allowed to inspect other processes, then try again."
        case .noVisibleApplications:
            return "Open a regular application and refresh AppMonitor."
        }
    }
}
