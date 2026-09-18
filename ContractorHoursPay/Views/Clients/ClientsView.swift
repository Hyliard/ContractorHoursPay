import SwiftUI

struct ClientsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var viewModel = ClientsViewModel()
    @State private var isShowingAddClient = false

    var body: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            if viewModel.includeInactive {
                activeSection
                archivedSection
            } else {
                activeRows
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.clients.isEmpty {
                ProgressView()
            } else if !viewModel.isLoading && viewModel.clients.isEmpty {
                ContentUnavailableView("Sin clientes", systemImage: "person.crop.square.badge.questionmark")
            }
        }
        .navigationTitle("Clientes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddClient = true
                } label: {
                    Label("Nuevo cliente", systemImage: "plus")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Ver archivados", isOn: $viewModel.includeInactive)
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task {
            await viewModel.load(using: authManager)
        }
        .refreshable {
            await viewModel.load(using: authManager)
        }
        .onChange(of: viewModel.includeInactive) {
            Task {
                await viewModel.load(using: authManager)
            }
        }
        .sheet(isPresented: $isShowingAddClient) {
            AddClientView(clientsViewModel: viewModel)
                .environmentObject(authManager)
        }
    }

    private var activeRows: some View {
        ForEach(viewModel.activeClients) { client in
            NavigationLink {
                ClientDetailView(client: client, clientsViewModel: viewModel)
            } label: {
                ClientRowView(client: client)
            }
        }
    }

    private var activeSection: some View {
        Section("Activos") {
            if viewModel.activeClients.isEmpty {
                Text("No hay clientes activos.")
                    .foregroundStyle(.secondary)
            } else {
                activeRows
            }
        }
    }

    private var archivedSection: some View {
        Section("Archivados") {
            if viewModel.archivedClients.isEmpty {
                Text("No hay clientes archivados.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.archivedClients) { client in
                    NavigationLink {
                        ClientDetailView(client: client, clientsViewModel: viewModel)
                    } label: {
                        ClientRowView(client: client)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ClientsView()
            .environmentObject(AuthManager())
    }
}
