import SwiftUI

struct NetworkDebugView: View {
    @ObservedObject private var store = NetworkDebugStore.shared

    var body: some View {
        List {
            if store.entries.isEmpty {
                ContentUnavailableView("No network logs", systemImage: "network.slash")
            } else {
                ForEach(store.entries) { entry in
                    NavigationLink {
                        NetworkDebugDetailView(entry: entry)
                    } label: {
                        NetworkDebugRow(entry: entry)
                    }
                }
            }
        }
        .navigationTitle("Network Debug")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear") {
                    store.clear()
                }
                .disabled(store.entries.isEmpty)
            }
        }
    }
}

private struct NetworkDebugRow: View {
    let entry: NetworkDebugEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.method)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(methodColor)
                    .frame(width: 44, alignment: .leading)

                Text(entry.endpoint)
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer()

                Text(entry.statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            HStack {
                Text("\(entry.durationMs) ms")
                Text(entry.timestamp.formatted(.dateTime.hour().minute().second()))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var methodColor: Color {
        switch entry.method {
        case "GET": .blue
        case "POST": .green
        case "PATCH": .orange
        case "DELETE": .red
        default: .secondary
        }
    }

    private var statusColor: Color {
        guard let statusCode = entry.statusCode else { return Color.red }
        switch statusCode {
        case 200..<300:
            return Color.green
        case 400..<500:
            return Color.orange
        case 500..<600:
            return Color.red
        default:
            return Color.secondary
        }
    }
}

private struct NetworkDebugDetailView: View {
    let entry: NetworkDebugEntry

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Method", value: entry.method)
                LabeledContent("Endpoint", value: entry.endpoint)
                LabeledContent("Status", value: entry.statusText)
                LabeledContent("Duration", value: "\(entry.durationMs) ms")
                LabeledContent("Timestamp", value: entry.timestamp.formatted(.dateTime.year().month().day().hour().minute().second()))
            }

            if let errorMessage = entry.errorMessage {
                Section("Error") {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section("Request Preview") {
                Text(entry.requestPreview ?? "N/A")
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }

            Section("Response Preview") {
                Text(entry.responsePreview ?? "N/A")
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("Request")
        .navigationBarTitleDisplayMode(.inline)
    }
}
