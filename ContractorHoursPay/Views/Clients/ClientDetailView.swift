import SwiftUI

struct ClientDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject var clientsViewModel: ClientsViewModel

    @State private var client: Client
    @State private var isLoading = false
    @State private var isArchiving = false
    @State private var errorMessage: String?
    @State private var isShowingEdit = false
    @State private var isShowingArchiveConfirmation = false

    init(client: Client, clientsViewModel: ClientsViewModel) {
        _client = State(initialValue: client)
        self.clientsViewModel = clientsViewModel
    }

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(client.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(client.active ? "Activo" : "Archivado")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((client.active ? Color.green : Color.secondary).opacity(0.14), in: Capsule())
                        .foregroundStyle(client.active ? .green : .secondary)
                }
                .padding(.vertical, 6)
            }

            Section("Información") {
                if let company = client.company, !company.isEmpty {
                    LabeledContent("Empresa", value: company)
                }

                if let email = client.email, !email.isEmpty {
                    LabeledContent("Email", value: email)
                }

                LabeledContent("Creado", value: client.createdAt.formatted(.dateTime.day().month().year()))
            }

            Section {
                Button {
                    isShowingEdit = true
                } label: {
                    Label("Editar", systemImage: "square.and.pencil")
                }

                Button(role: .destructive) {
                    isShowingArchiveConfirmation = true
                } label: {
                    if isArchiving {
                        ProgressView()
                    } else {
                        Label("Archivar cliente", systemImage: "archivebox")
                    }
                }
                .disabled(isArchiving || !client.active)
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .navigationTitle("Cliente")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refresh()
        }
        .refreshable {
            await refresh()
        }
        .sheet(isPresented: $isShowingEdit) {
            EditClientView(client: client, clientsViewModel: clientsViewModel) { updatedClient in
                client = updatedClient
            }
            .environmentObject(authManager)
        }
        .confirmationDialog(
            "¿Archivar \(client.name)?",
            isPresented: $isShowingArchiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Archivar cliente", role: .destructive) {
                Task {
                    await archive()
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("El cliente dejará de aparecer en la lista activa, pero su información no se eliminará permanentemente.")
        }
    }

    private func refresh() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            client = try await clientsViewModel.fetchClient(id: client.id, using: authManager)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func archive() async {
        errorMessage = nil
        isArchiving = true
        defer { isArchiving = false }

        do {
            try await clientsViewModel.archive(client, using: authManager)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
