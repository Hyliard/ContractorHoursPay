import SwiftUI

struct EditContractView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject var contractsViewModel: ContractsViewModel

    let contract: Contract
    let onSaved: (Contract) -> Void

    @State private var clients: [Client] = []
    @State private var selectedClientId: String
    @State private var name: String
    @State private var hourlyRate: String
    @State private var currency: String
    @State private var overtimeRate: String
    @State private var active: Bool
    @State private var hasStartDate: Bool
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let currencies = ["USD", "ARS", "EUR"]
    private let clientService = ClientAPIService()

    init(contract: Contract, contractsViewModel: ContractsViewModel, onSaved: @escaping (Contract) -> Void) {
        self.contract = contract
        self.contractsViewModel = contractsViewModel
        self.onSaved = onSaved
        _selectedClientId = State(initialValue: contract.clientId)
        _name = State(initialValue: contract.name)
        _hourlyRate = State(initialValue: contract.hourlyRate)
        _currency = State(initialValue: contract.currency)
        _overtimeRate = State(initialValue: contract.overtimeRate ?? "")
        _active = State(initialValue: contract.active)
        _hasStartDate = State(initialValue: contract.startDate != nil)
        _startDate = State(initialValue: contract.startDate ?? Date())
        _hasEndDate = State(initialValue: contract.endDate != nil)
        _endDate = State(initialValue: contract.endDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contrato") {
                    Picker("Cliente", selection: $selectedClientId) {
                        ForEach(clients) { client in
                            Text(client.id == contract.clientId && !client.active ? "\(client.name) (archivado)" : client.name)
                                .tag(client.id)
                        }
                    }

                    TextField("Nombre", text: $name)

                    TextField("Tarifa por hora", text: $hourlyRate)
                        .keyboardType(.decimalPad)

                    Picker("Moneda", selection: $currency) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency)
                        }
                    }

                    TextField("Overtime opcional", text: $overtimeRate)
                        .keyboardType(.decimalPad)

                    Toggle("Activo", isOn: $active)
                }

                Section("Fechas") {
                    Toggle("Fecha de inicio", isOn: $hasStartDate)
                    if hasStartDate {
                        DatePicker("Inicio", selection: $startDate, displayedComponents: .date)
                    }

                    Toggle("Fecha de fin", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("Fin", selection: $endDate, displayedComponents: .date)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Editar contrato")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await save()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Guardar")
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .task {
                await loadClients()
            }
        }
    }

    private var canSave: Bool {
        !selectedClientId.isEmpty
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && isValidPositiveDecimal(hourlyRate)
            && !isLoading
    }

    private func loadClients() async {
        errorMessage = nil
        do {
            guard let token = authManager.token else { throw APIError.notAuthenticated }
            clients = try await clientService.getClients(includeInactive: false, token: token)
            if !clients.contains(where: { $0.id == contract.clientId }) {
                clients.insert(
                    Client(
                        id: contract.client.id,
                        userId: "",
                        name: contract.client.name,
                        email: nil,
                        company: contract.client.company,
                        active: false,
                        createdAt: .now,
                        updatedAt: .now
                    ),
                    at: 0
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedHourlyRate = normalizedRate(hourlyRate)
        let normalizedOvertimeRate = normalizedOptional(normalizedRate(overtimeRate))

        guard !trimmedName.isEmpty else {
            errorMessage = "Ingresá el nombre del contrato."
            return
        }
        guard isValidPositiveDecimal(normalizedHourlyRate) else {
            errorMessage = "Ingresá una tarifa válida."
            return
        }
        guard normalizedOvertimeRate == nil || isValidPositiveDecimal(normalizedOvertimeRate ?? "") else {
            errorMessage = "Ingresá un overtime válido."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let updatedContract = try await contractsViewModel.update(
                id: contract.id,
                clientId: selectedClientId,
                name: trimmedName,
                hourlyRate: normalizedHourlyRate,
                currency: currency,
                overtimeRate: normalizedOvertimeRate,
                active: active,
                startDate: hasStartDate ? startDate : nil,
                endDate: hasEndDate ? endDate : nil,
                using: authManager
            )
            onSaved(updatedContract)
            dismiss()
        } catch {
            errorMessage = userFacingError(error)
        }
    }
}
