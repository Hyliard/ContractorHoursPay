import SwiftUI

struct AddContractView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject var contractsViewModel: ContractsViewModel

    let preselectedClient: Client?

    @State private var clients: [Client] = []
    @State private var selectedClientId = ""
    @State private var name = ""
    @State private var hourlyRate = ""
    @State private var currency = "USD"
    @State private var overtimeRate = ""
    @State private var hasStartDate = false
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let currencies = ["USD", "ARS", "EUR"]
    private let clientService = ClientAPIService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Contrato") {
                    Picker("Cliente", selection: $selectedClientId) {
                        ForEach(clients) { client in
                            Text(client.name)
                                .tag(client.id)
                        }
                    }
                    .disabled(preselectedClient != nil)

                    TextField("Nombre", text: $name)

                    TextField("Tarifa por hora", text: $hourlyRate)
                        .keyboardType(.decimalPad)

                    Picker("Moneda", selection: $currency) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency)
                        }
                    }

                    TextField("Horas extra opcional", text: $overtimeRate)
                        .keyboardType(.decimalPad)
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
            .navigationTitle("Nuevo contrato")
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
            if let preselectedClient {
                if preselectedClient.active {
                    selectedClientId = preselectedClient.id
                    if !clients.contains(where: { $0.id == preselectedClient.id }) {
                        clients.insert(preselectedClient, at: 0)
                    }
                } else {
                    errorMessage = "No se puede crear un contrato para un cliente archivado."
                }
            } else if selectedClientId.isEmpty {
                selectedClientId = clients.first?.id ?? ""
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
        guard !selectedClientId.isEmpty else {
            errorMessage = "Seleccioná un cliente activo."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await contractsViewModel.create(
                clientId: selectedClientId,
                name: trimmedName,
                hourlyRate: normalizedHourlyRate,
                currency: currency,
                overtimeRate: normalizedOvertimeRate,
                startDate: hasStartDate ? startDate : nil,
                endDate: hasEndDate ? endDate : nil,
                using: authManager
            )
            dismiss()
        } catch {
            errorMessage = userFacingError(error)
        }
    }
}
