import SwiftUI

struct ContractDetailView: View {
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject var contractsViewModel: ContractsViewModel

    @State private var contract: Contract
    @State private var isLoading = false
    @State private var isUpdatingStatus = false
    @State private var errorMessage: String?
    @State private var isShowingEdit = false
    @State private var isShowingArchiveConfirmation = false
    @State private var isShowingReactivateConfirmation = false

    init(contract: Contract, contractsViewModel: ContractsViewModel) {
        _contract = State(initialValue: contract)
        self.contractsViewModel = contractsViewModel
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
                    Text(contract.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(contract.active ? "Activo" : "Archivado")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((contract.active ? Color.green : Color.secondary).opacity(0.14), in: Capsule())
                        .foregroundStyle(contract.active ? .green : .secondary)
                }
                .padding(.vertical, 6)
            }

            Section("Información") {
                LabeledContent("Cliente", value: contract.client.name)
                if let company = contract.client.company, !company.isEmpty {
                    LabeledContent("Empresa", value: company)
                }
                LabeledContent("Tarifa", value: "\(contract.hourlyRate) \(contract.currency)/h")
                if let overtimeRate = contract.overtimeRate, !overtimeRate.isEmpty {
                    LabeledContent("Overtime", value: "\(overtimeRate) \(contract.currency)/h")
                }
                if let startDate = contract.startDate {
                    LabeledContent("Inicio", value: startDate.formatted(.dateTime.day().month().year()))
                }
                if let endDate = contract.endDate {
                    LabeledContent("Fin", value: endDate.formatted(.dateTime.day().month().year()))
                }
            }

            Section {
                Button {
                    isShowingEdit = true
                } label: {
                    Label("Editar", systemImage: "square.and.pencil")
                }

                Button(role: contract.active ? .destructive : nil) {
                    if contract.active {
                        isShowingArchiveConfirmation = true
                    } else {
                        isShowingReactivateConfirmation = true
                    }
                } label: {
                    if isUpdatingStatus {
                        ProgressView()
                    } else {
                        Label(contract.active ? "Archivar contrato" : "Reactivar contrato", systemImage: contract.active ? "archivebox" : "arrow.uturn.backward.circle")
                    }
                }
                .disabled(isUpdatingStatus)
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .navigationTitle("Contrato")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refresh()
        }
        .refreshable {
            await refresh()
        }
        .sheet(isPresented: $isShowingEdit) {
            EditContractView(contract: contract, contractsViewModel: contractsViewModel) { updatedContract in
                contract = updatedContract
            }
            .environmentObject(authManager)
        }
        .confirmationDialog("¿Archivar \(contract.name)?", isPresented: $isShowingArchiveConfirmation, titleVisibility: .visible) {
            Button("Archivar contrato", role: .destructive) {
                Task {
                    await archive()
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("El contrato dejará de aparecer en la lista activa, pero su información no se eliminará permanentemente.")
        }
        .confirmationDialog("¿Reactivar \(contract.name)?", isPresented: $isShowingReactivateConfirmation, titleVisibility: .visible) {
            Button("Reactivar contrato") {
                Task {
                    await reactivate()
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func refresh() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            contract = try await contractsViewModel.fetchContract(id: contract.id, using: authManager)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func archive() async {
        errorMessage = nil
        isUpdatingStatus = true
        defer { isUpdatingStatus = false }

        do {
            contract = try await contractsViewModel.archive(contract, using: authManager)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reactivate() async {
        errorMessage = nil
        isUpdatingStatus = true
        defer { isUpdatingStatus = false }

        do {
            contract = try await contractsViewModel.update(
                id: contract.id,
                clientId: contract.clientId,
                name: contract.name,
                hourlyRate: contract.hourlyRate,
                currency: contract.currency,
                overtimeRate: contract.overtimeRate,
                active: true,
                startDate: contract.startDate,
                endDate: contract.endDate,
                using: authManager
            )
        } catch {
            errorMessage = userFacingError(error)
        }
    }
}
