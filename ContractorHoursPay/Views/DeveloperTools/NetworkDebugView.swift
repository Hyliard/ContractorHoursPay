import SwiftUI

struct NetworkDebugView: View {
    @ObservedObject private var store = NetworkDebugStore.shared

    var body: some View {
        List {
            if store.entries.isEmpty {
                ContentUnavailableView("No hay logs de red", systemImage: "network.slash")
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
        .navigationTitle("Depuración de red")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Limpiar") {
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
            Section("Resumen") {
                LabeledContent("Método", value: entry.method)
                LabeledContent("Endpoint", value: entry.endpoint)
                LabeledContent("Estado", value: entry.statusText)
                LabeledContent("Duración", value: "\(entry.durationMs) ms")
                LabeledContent("Fecha y hora", value: entry.timestamp.formatted(.dateTime.year().month().day().hour().minute().second()))
            }

            if let errorMessage = entry.errorMessage {
                Section("Error") {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section("Vista previa del request") {
                Text(entry.requestPreview ?? "N/D")
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }

            Section("Vista previa de la respuesta") {
                Text(entry.responsePreview ?? "N/D")
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("Request")
        .navigationBarTitleDisplayMode(.inline)
    }
}
