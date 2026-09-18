import SwiftUI

struct ContractsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var viewModel: ContractsViewModel
    @State private var isShowingAddContract = false

    private let preselectedClient: Client?

    init(clientId: String? = nil, preselectedClient: Client? = nil) {
        _viewModel = StateObject(wrappedValue: ContractsViewModel(clientId: clientId))
        self.preselectedClient = preselectedClient
    }

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
            if viewModel.isLoading && viewModel.contracts.isEmpty {
                ProgressView()
            } else if !viewModel.isLoading && viewModel.contracts.isEmpty {
                ContentUnavailableView("Sin contratos", systemImage: "doc.text.magnifyingglass")
            }
        }
        .navigationTitle("Contratos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddContract = true
                } label: {
                    Label("Nuevo contrato", systemImage: "plus")
                }
                .disabled(preselectedClient?.active == false)
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
        .sheet(isPresented: $isShowingAddContract) {
            AddContractView(contractsViewModel: viewModel, preselectedClient: preselectedClient)
                .environmentObject(authManager)
        }
    }

    private var activeRows: some View {
        ForEach(viewModel.activeContracts) { contract in
            NavigationLink {
                ContractDetailView(contract: contract, contractsViewModel: viewModel)
            } label: {
                ContractRowView(contract: contract)
            }
        }
    }

    private var activeSection: some View {
        Section("Activos") {
            if viewModel.activeContracts.isEmpty {
                Text("No hay contratos activos.")
                    .foregroundStyle(.secondary)
            } else {
                activeRows
            }
        }
    }

    private var archivedSection: some View {
        Section("Archivados") {
            if viewModel.archivedContracts.isEmpty {
                Text("No hay contratos archivados.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.archivedContracts) { contract in
                    NavigationLink {
                        ContractDetailView(contract: contract, contractsViewModel: viewModel)
                    } label: {
                        ContractRowView(contract: contract)
                    }
                }
            }
        }
    }
}
