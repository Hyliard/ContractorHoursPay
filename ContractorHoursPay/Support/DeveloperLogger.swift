import Foundation
import Combine

enum DeveloperLogType: String, CaseIterable, Identifiable {
    case info = "INFO"
    case network = "NETWORK"
    case auth = "AUTH"
    case error = "ERROR"

    var id: String { rawValue }
}

struct DeveloperLogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let type: DeveloperLogType
    let message: String

    var exportLine: String {
        "\(Self.timeFormatter.string(from: timestamp)) \(type.rawValue) \(message)"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

@MainActor
final class DeveloperLogger: ObservableObject {
    static let shared = DeveloperLogger()

    @Published private(set) var entries: [DeveloperLogEntry] = []

    private let maxEntries = 500

    private init() {}

    func log(_ type: DeveloperLogType, _ message: String) {
        let sanitized = DeveloperLogSanitizer.sanitizedText(message)
        entries.insert(DeveloperLogEntry(timestamp: Date(), type: type, message: sanitized), at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }

    func exportText(filteredBy type: DeveloperLogType? = nil) -> String {
        let filtered = entries
            .filter { type == nil || $0.type == type }
            .reversed()
        return filtered.map(\.exportLine).joined(separator: "\n")
    }
}
