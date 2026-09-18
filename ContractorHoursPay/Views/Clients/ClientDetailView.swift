import SwiftUI

struct ClientDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject var clientsViewModel: ClientsViewModel
    @StateObject private var contractsViewModel: ContractsViewModel

    @State private var client: Client
    @State private var isLoading = false
    @State private var isArchiving = false
    @State private var errorMessage: String?
    @State private var isShowingEdit = false
    @State private var isShowingAddContract = false
    @State private var isShowingArchiveConfirmation = false

    init(client: Client, clientsViewModel: ClientsViewModel) {
        _client = State(initialValue: client)
        _contractsViewModel = StateObject(wrappedValue: ContractsViewModel(clientId: client.id, includeInactive: true))
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
                contractsContent
            } header: {
                HStack {
                    Text("Contracts")
                    Spacer()
                    if client.active {
                        Button {
                            isShowingAddContract = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)
                    }
                }
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
            await contractsViewModel.load(using: authManager)
        }
        .refreshable {
            await refresh()
            await contractsViewModel.load(using: authManager)
        }
        .sheet(isPresented: $isShowingEdit) {
            EditClientView(client: client, clientsViewModel: clientsViewModel) { updatedClient in
                client = updatedClient
            }
            .environmentObject(authManager)
        }
        .sheet(isPresented: $isShowingAddContract) {
            AddContractView(contractsViewModel: contractsViewModel, preselectedClient: client)
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

    @ViewBuilder
    private var contractsContent: some View {
        if contractsViewModel.isLoading && contractsViewModel.contracts.isEmpty {
            ProgressView()
        } else if let errorMessage = contractsViewModel.errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
        } else if contractsViewModel.contracts.isEmpty {
            Text(client.active ? "No hay contratos para este cliente." : "Este cliente archivado no tiene contratos.")
                .foregroundStyle(.secondary)
        } else {
            ForEach(contractsViewModel.contracts) { contract in
                NavigationLink {
                    ContractDetailView(contract: contract, contractsViewModel: contractsViewModel)
                } label: {
                    ContractRowView(contract: contract)
                }
            }

            NavigationLink {
                ContractsView(clientId: client.id, preselectedClient: client)
            } label: {
                Label("Ver todos", systemImage: "doc.text.magnifyingglass")
            }
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
