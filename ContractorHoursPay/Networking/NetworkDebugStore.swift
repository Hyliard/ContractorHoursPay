import Foundation
import Combine

struct NetworkDebugEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let method: String
    let endpoint: String
    let statusCode: Int?
    let durationMs: Int
    let errorMessage: String?
    let requestPreview: String?
    let responsePreview: String?

    var statusText: String {
        if let statusCode {
            return String(statusCode)
        }
        return errorMessage == nil ? "N/A" : "ERR"
    }
}

@MainActor
final class NetworkDebugStore: ObservableObject {
    static let shared = NetworkDebugStore()

    @Published private(set) var entries: [NetworkDebugEntry] = []

    private let maxEntries = 100

    private init() {}

    func add(_ entry: NetworkDebugEntry) {
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }
}
