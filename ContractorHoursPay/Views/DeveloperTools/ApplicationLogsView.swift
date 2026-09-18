import SwiftUI
import UIKit

struct ApplicationLogsView: View {
    @ObservedObject private var logger = DeveloperLogger.shared
    @State private var filter: ApplicationLogFilter = .all
    @State private var didCopy = false

    var body: some View {
        List {
            Section {
                Picker("Filter", selection: $filter) {
                    ForEach(ApplicationLogFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            if filteredEntries.isEmpty {
                ContentUnavailableView("No logs", systemImage: "doc.text")
            } else {
                ForEach(filteredEntries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.timestamp.formatted(.dateTime.hour().minute().second()))
                                .foregroundStyle(.secondary)
                            Text(entry.type.rawValue)
                                .fontWeight(.semibold)
                                .foregroundStyle(color(for: entry.type))
                        }
                        .font(.caption)

                        Text(entry.message)
                            .font(.footnote)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .navigationTitle("Application Logs")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: exportText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(exportText.isEmpty)

                Button {
                    UIPasteboard.general.string = exportText
                    didCopy = true
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .disabled(exportText.isEmpty)

                Button("Clear") {
                    logger.clear()
                }
                .disabled(logger.entries.isEmpty)
            }
        }
        .alert("Logs copied", isPresented: $didCopy) {
            Button("OK", role: .cancel) {}
        }
    }

    private var filteredEntries: [DeveloperLogEntry] {
        logger.entries.filter { filter.type == nil || $0.type == filter.type }
    }

    private var exportText: String {
        logger.exportText(filteredBy: filter.type)
    }

    private func color(for type: DeveloperLogType) -> Color {
        switch type {
        case .info: .secondary
        case .network: .blue
        case .auth: .green
        case .error: .red
        }
    }
}

private enum ApplicationLogFilter: String, CaseIterable, Identifiable {
    case all
    case network
    case auth
    case error

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .network: "Network"
        case .auth: "Auth"
        case .error: "Error"
        }
    }

    var type: DeveloperLogType? {
        switch self {
        case .all: nil
        case .network: .network
        case .auth: .auth
        case .error: .error
        }
    }
}
