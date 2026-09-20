import SwiftUI

struct ContractDetailView: View {
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject var contractsViewModel: ContractsViewModel
    @StateObject private var workLogsViewModel: WorkLogsViewModel
    @StateObject private var invoicesViewModel: InvoicesViewModel

    @State private var contract: Contract
    @State private var isLoading = false
    @State private var isUpdatingStatus = false
    @State private var errorMessage: String?
    @State private var isShowingEdit = false
    @State private var isShowingAddWorkLog = false
    @State private var isShowingAddInvoice = false
    @State private var isShowingArchiveConfirmation = false
    @State private var isShowingReactivateConfirmation = false

    init(contract: Contract, contractsViewModel: ContractsViewModel) {
        _contract = State(initialValue: contract)
        _workLogsViewModel = StateObject(wrappedValue: WorkLogsViewModel(contractId: contract.id))
        _invoicesViewModel = StateObject(wrappedValue: InvoicesViewModel(contractId: contract.id, includeInactive: true))
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
                    LabeledContent("Horas extra", value: "\(overtimeRate) \(contract.currency)/h")
                }
                if let startDate = contract.startDate {
                    LabeledContent("Inicio", value: startDate.formatted(.dateTime.day().month().year()))
                }
                if let endDate = contract.endDate {
                    LabeledContent("Fin", value: endDate.formatted(.dateTime.day().month().year()))
                }
            }

            Section("Registros de horas") {
                if let errorMessage = workLogsViewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if workLogsViewModel.isLoading && workLogsViewModel.workLogs.isEmpty {
                    ProgressView()
                } else if workLogsViewModel.workLogs.isEmpty {
                    Text("No hay registros para este contrato.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workLogsViewModel.workLogs.prefix(5)) { workLog in
                        NavigationLink {
                            WorkLogDetailView(workLog: workLog, workLogsViewModel: workLogsViewModel)
                        } label: {
                            WorkLogRowView(workLog: workLog)
                        }
                    }
                }

                if contract.active {
                    Button {
                        isShowingAddWorkLog = true
                    } label: {
                        Label("Nuevo registro", systemImage: "plus")
                    }
                } else {
                    Text("Este contrato está archivado. Podés ver registros existentes, pero no crear nuevos.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    WorkLogsView(contractId: contract.id, preselectedContract: contract)
                } label: {
                    Label("Ver todos", systemImage: "list.bullet")
                }
            }

            Section("Facturas") {
                if let errorMessage = invoicesViewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if invoicesViewModel.isLoading && invoicesViewModel.invoices.isEmpty {
                    ProgressView()
                } else if invoicesViewModel.invoices.isEmpty {
                    Text("No hay facturas para este contrato.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(invoicesViewModel.invoices.prefix(5)) { invoice in
                        NavigationLink {
                            InvoiceDetailView(invoice: invoice, invoicesViewModel: invoicesViewModel)
                        } label: {
                            InvoiceRowView(invoice: invoice)
                        }
                    }
                }

                if contract.active {
                    Button {
                        isShowingAddInvoice = true
                    } label: {
                        Label("Nueva factura", systemImage: "plus")
                    }
                } else {
                    Text("Este contrato está archivado. Podés ver facturas existentes, pero no crear nuevas.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    InvoicesView(contractId: contract.id, preselectedContract: contract)
                } label: {
                    Label("Ver todas", systemImage: "doc.text.magnifyingglass")
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
            await workLogsViewModel.load(using: authManager)
            await invoicesViewModel.load(using: authManager)
        }
        .refreshable {
            await refresh()
            await workLogsViewModel.load(using: authManager)
            await invoicesViewModel.load(using: authManager)
        }
        .sheet(isPresented: $isShowingEdit) {
            EditContractView(contract: contract, contractsViewModel: contractsViewModel) { updatedContract in
                contract = updatedContract
            }
            .environmentObject(authManager)
        }
        .sheet(isPresented: $isShowingAddWorkLog) {
            AddWorkLogView(workLogsViewModel: workLogsViewModel, preselectedContract: contract)
                .environmentObject(authManager)
        }
        .sheet(isPresented: $isShowingAddInvoice, onDismiss: {
            Task { await invoicesViewModel.load(using: authManager) }
        }) {
            AddInvoiceView(invoicesViewModel: invoicesViewModel, preselectedClient: nil, preselectedContract: contract)
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
