import SwiftUI

struct EditWorkLogView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject var workLogsViewModel: WorkLogsViewModel

    let workLog: WorkLog
    let onSaved: (WorkLog) -> Void

    @State private var contracts: [Contract] = []
    @State private var selectedContractId: String
    @State private var workDate: Date
    @State private var hours: String
    @State private var isOvertime: Bool
    @State private var note: String
    @State private var active: Bool
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let contractService = ContractAPIService()

    init(workLog: WorkLog, workLogsViewModel: WorkLogsViewModel, onSaved: @escaping (WorkLog) -> Void) {
        self.workLog = workLog
        self.workLogsViewModel = workLogsViewModel
        self.onSaved = onSaved
        _selectedContractId = State(initialValue: workLog.contractId)
        _workDate = State(initialValue: workLog.workDate)
        _hours = State(initialValue: workLog.hours)
        _isOvertime = State(initialValue: workLog.isOvertime)
        _note = State(initialValue: workLog.note ?? "")
        _active = State(initialValue: workLog.active)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Registro") {
                    Picker("Contrato", selection: $selectedContractId) {
                        ForEach(contracts) { contract in
                            Text(contract.id == workLog.contractId && !contract.active ? "\(contract.name) (archivado)" : contract.name)
                                .tag(contract.id)
                        }
                    }

                    DatePicker("Fecha", selection: $workDate, displayedComponents: .date)

                    TextField("Horas", text: $hours)
                        .keyboardType(.decimalPad)

                    Toggle("Overtime", isOn: $isOvertime)

                    Toggle("Activo", isOn: $active)
                }

                Section("Nota") {
                    TextField("Opcional", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .onChange(of: note) {
                            if note.count > 2_000 {
                                note = String(note.prefix(2_000))
                            }
                        }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Editar registro")
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
                await loadContracts()
            }
        }
    }

    private var canSave: Bool {
        !selectedContractId.isEmpty
            && isValidPositiveDecimal(hours)
            && note.count <= 2_000
            && !isLoading
    }

    private func loadContracts() async {
        errorMessage = nil
        do {
            guard let token = authManager.token else { throw APIError.notAuthenticated }
            contracts = try await contractService.fetchContracts(includeInactive: false, token: token)
            if !contracts.contains(where: { $0.id == workLog.contractId }) {
                contracts.insert(currentContractPlaceholder, at: 0)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var currentContractPlaceholder: Contract {
        Contract(
            id: workLog.contract.id,
            clientId: "",
            name: workLog.contract.name,
            hourlyRate: workLog.contract.hourlyRate,
            currency: workLog.contract.currency,
            overtimeRate: nil,
            active: false,
            startDate: nil,
            endDate: nil,
            createdAt: .now,
            updatedAt: .now,
            client: ContractClientSummary(
                id: workLog.contract.client.id,
                name: workLog.contract.client.name,
                company: workLog.contract.client.company
            )
        )
    }

    private func save() async {
        errorMessage = nil

        let normalizedHours = normalizedRate(hours)
        let trimmedNote = normalizedOptional(note)

        guard !selectedContractId.isEmpty else {
            errorMessage = "Seleccioná un contrato."
            return
        }
        guard isValidPositiveDecimal(normalizedHours) else {
            errorMessage = "Ingresá una cantidad de horas válida."
            return
        }
        guard note.count <= 2_000 else {
            errorMessage = "La nota no puede superar 2000 caracteres."
            return
        }
        if selectedContractId != workLog.contractId {
            guard contracts.contains(where: { $0.id == selectedContractId && $0.active }) else {
                errorMessage = "Elegí un contrato activo."
                return
            }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let updatedWorkLog = try await workLogsViewModel.update(
                id: workLog.id,
                contractId: selectedContractId,
                workDate: workDate,
                hours: normalizedHours,
                isOvertime: isOvertime,
                note: trimmedNote,
                active: active,
                using: authManager
            )
            onSaved(updatedWorkLog)
            dismiss()
        } catch {
            errorMessage = userFacingWorkLogError(error)
        }
    }
}
