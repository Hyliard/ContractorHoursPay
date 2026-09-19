import SwiftUI

struct AddInvoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject var invoicesViewModel: InvoicesViewModel

    let preselectedClient: Client?
    let preselectedContract: Contract?

    @State private var clients: [Client] = []
    @State private var contracts: [Contract] = []
    @State private var workLogs: [WorkLog] = []
    @State private var selectedClientId = ""
    @State private var selectedContractId = ""
    @State private var periodFrom = Date()
    @State private var periodTo = Date()
    @State private var currency = "USD"
    @State private var subtotal = ""
    @State private var issuedAt = Date()
    @State private var hasDueDate = true
    @State private var dueDate = Date()
    @State private var note = ""
    @State private var selectedWorkLogIds: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let clientService = ClientAPIService()
    private let contractService = ContractAPIService()
    private let workLogService = WorkLogAPIService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Invoice") {
                    Picker("Client", selection: $selectedClientId) {
                        ForEach(clients) { client in
                            Text(client.name).tag(client.id)
                        }
                    }
                    .disabled(preselectedClient != nil)

                    Picker("Contract", selection: $selectedContractId) {
                        Text("None").tag("")
                        ForEach(filteredContracts) { contract in
                            Text(contract.name).tag(contract.id)
                        }
                    }
                    .disabled(preselectedContract != nil)

                    TextField("Currency", text: $currency)
                        .textInputAutocapitalization(.characters)
                        .onChange(of: currency) { currency = String(currency.uppercased().prefix(3)) }

                    TextField("Subtotal", text: $subtotal)
                        .keyboardType(.decimalPad)

                    if let suggestedSubtotal {
                        Button("Use suggested subtotal \(suggestedSubtotal.formattedCurrency(code: currency))") {
                            subtotal = NSDecimalNumber(decimal: suggestedSubtotal).stringValue
                        }
                    }
                }

                Section("Period") {
                    DatePicker("From", selection: $periodFrom, displayedComponents: .date)
                    DatePicker("To", selection: $periodTo, displayedComponents: .date)
                    DatePicker("Issued", selection: $issuedAt, displayedComponents: .date)
                    Toggle("Due Date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section("Work Logs") {
                    if matchingWorkLogs.isEmpty {
                        Text("No matching WorkLogs.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(matchingWorkLogs) { workLog in
                            Button {
                                toggleWorkLog(workLog.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(workLog.workDate.formatted(.dateTime.day().month().year()))
                                        Text("\(workLog.hours) h · \(workLog.contract.name)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: selectedWorkLogIds.contains(workLog.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedWorkLogIds.contains(workLog.id) ? .green : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Note") {
                    TextField("Optional", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .task {
                await loadDependencies()
            }
            .onChange(of: selectedClientId) {
                selectedWorkLogIds.removeAll()
                if preselectedContract == nil,
                   !filteredContracts.contains(where: { $0.id == selectedContractId }) {
                    selectedContractId = ""
                }
            }
            .onChange(of: selectedContractId) {
                selectedWorkLogIds.removeAll()
            }
        }
    }

    private var filteredContracts: [Contract] {
        contracts.filter { contract in
            contract.active && (selectedClientId.isEmpty || contract.clientId == selectedClientId)
        }
    }

    private var matchingWorkLogs: [WorkLog] {
        workLogs.filter { workLog in
            workLog.active
                && (selectedContractId.isEmpty || workLog.contractId == selectedContractId)
                && (selectedClientId.isEmpty || workLog.contract.client.id == selectedClientId)
                && workLog.workDate >= periodFrom.startOfBusinessDay
                && workLog.workDate <= periodTo.startOfBusinessDay
        }
    }

    private var suggestedSubtotal: Decimal? {
        let total = matchingWorkLogs
            .filter { selectedWorkLogIds.contains($0.id) }
            .reduce(Decimal(0)) { partial, workLog in
                guard let hours = decimalValue(workLog.hours),
                      let rate = decimalValue(workLog.contract.hourlyRate),
                      workLog.contract.currency == currency else {
                    return partial
                }
                return partial + (hours * rate)
            }
        return total > 0 ? total : nil
    }

    private var canSave: Bool {
        !selectedClientId.isEmpty
            && isValidPositiveDecimal(subtotal)
            && isValidCurrencyCode(currency)
            && periodFrom.startOfBusinessDay <= periodTo.startOfBusinessDay
            && (!hasDueDate || dueDate.startOfBusinessDay >= issuedAt.startOfBusinessDay)
            && !isLoading
    }

    private func loadDependencies() async {
        errorMessage = nil
        do {
            guard let token = authManager.token else { throw APIError.notAuthenticated }
            async let fetchedClients = clientService.getClients(includeInactive: false, token: token)
            async let fetchedContracts = contractService.fetchContracts(includeInactive: false, token: token)
            async let fetchedWorkLogs = workLogService.fetchWorkLogs(includeInactive: false, token: token)

            clients = try await fetchedClients
            contracts = try await fetchedContracts
            workLogs = try await fetchedWorkLogs

            if let preselectedClient {
                selectedClientId = preselectedClient.id
                if !clients.contains(where: { $0.id == preselectedClient.id }) {
                    clients.insert(preselectedClient, at: 0)
                }
            } else if selectedClientId.isEmpty {
                selectedClientId = clients.first?.id ?? ""
            }

            if let preselectedContract {
                selectedContractId = preselectedContract.id
                selectedClientId = preselectedContract.clientId
                currency = preselectedContract.currency
                if !contracts.contains(where: { $0.id == preselectedContract.id }) {
                    contracts.insert(preselectedContract, at: 0)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleWorkLog(_ id: String) {
        if selectedWorkLogIds.contains(id) {
            selectedWorkLogIds.remove(id)
        } else {
            selectedWorkLogIds.insert(id)
        }
    }

    private func save() async {
        errorMessage = nil

        guard canSave else {
            errorMessage = "Revisá los datos de la factura."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await invoicesViewModel.create(
                clientId: selectedClientId,
                contractId: normalizedOptional(selectedContractId),
                periodFrom: periodFrom,
                periodTo: periodTo,
                currency: currency.uppercased(),
                subtotal: normalizedRate(subtotal),
                issuedAt: issuedAt,
                dueDate: hasDueDate ? dueDate : nil,
                note: normalizedOptional(note),
                workLogIds: Array(selectedWorkLogIds),
                using: authManager
            )
            dismiss()
        } catch {
            errorMessage = userFacingInvoiceError(error)
        }
    }
}
