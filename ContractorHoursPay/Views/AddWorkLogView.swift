import SwiftUI

struct AddWorkLogView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject private var workLogsViewModel: WorkLogsViewModel

    private let preselectedContract: Contract?
    private let ownsViewModel: Bool

    @State private var contracts: [Contract] = []
    @State private var selectedContractId = ""
    @State private var workDate = Date()
    @State private var hours = ""
    @State private var isOvertime = false
    @State private var note = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let contractService = ContractAPIService()

    init(workLogsViewModel: WorkLogsViewModel? = nil, preselectedContract: Contract? = nil) {
        self.preselectedContract = preselectedContract
        if let workLogsViewModel {
            self.workLogsViewModel = workLogsViewModel
            self.ownsViewModel = false
        } else {
            self.workLogsViewModel = WorkLogsViewModel()
            self.ownsViewModel = true
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Registro") {
                    Picker("Contrato", selection: $selectedContractId) {
                        ForEach(contracts) { contract in
                            Text(contract.name)
                                .tag(contract.id)
                        }
                    }
                    .disabled(preselectedContract != nil)

                    DatePicker("Fecha", selection: $workDate, displayedComponents: .date)

                    TextField("Horas", text: $hours)
                        .keyboardType(.decimalPad)

                    Toggle("Horas extra", isOn: $isOvertime)
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
            .navigationTitle("Registrar horas")
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
            if let preselectedContract {
                if preselectedContract.active {
                    selectedContractId = preselectedContract.id
                    if !contracts.contains(where: { $0.id == preselectedContract.id }) {
                        contracts.insert(preselectedContract, at: 0)
                    }
                } else {
                    errorMessage = "No se puede registrar horas para un contrato archivado."
                }
            } else if selectedContractId.isEmpty {
                selectedContractId = contracts.first?.id ?? ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        errorMessage = nil

        let normalizedHours = normalizedRate(hours)
        let trimmedNote = normalizedOptional(note)

        guard !selectedContractId.isEmpty else {
            errorMessage = "Seleccioná un contrato activo."
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
        guard contracts.contains(where: { $0.id == selectedContractId && $0.active }) else {
            errorMessage = "El contrato seleccionado no está activo."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await workLogsViewModel.create(
                contractId: selectedContractId,
                workDate: workDate,
                hours: normalizedHours,
                isOvertime: isOvertime,
                note: trimmedNote,
                using: authManager
            )
            if ownsViewModel {
                await workLogsViewModel.load(using: authManager)
            }
            dismiss()
        } catch {
            errorMessage = userFacingWorkLogError(error)
        }
    }
}
