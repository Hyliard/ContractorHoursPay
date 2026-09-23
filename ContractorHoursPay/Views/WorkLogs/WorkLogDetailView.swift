import SwiftUI

struct WorkLogDetailView: View {
    @EnvironmentObject private var authManager: AuthManager
    @AppStorage(AppPreferenceKey.confirmBeforeArchive) private var confirmBeforeArchive = true
    @AppStorage(AppPreferenceKey.highlightOvertime) private var highlightOvertime = true
    @AppStorage(AppPreferenceKey.hourFormat) private var hourFormat = "decimal"
    @ObservedObject var workLogsViewModel: WorkLogsViewModel

    @State private var workLog: WorkLog
    @State private var isLoading = false
    @State private var isUpdatingStatus = false
    @State private var errorMessage: String?
    @State private var isShowingEdit = false
    @State private var isShowingArchiveConfirmation = false
    @State private var isShowingReactivateConfirmation = false

    init(workLog: WorkLog, workLogsViewModel: WorkLogsViewModel) {
        _workLog = State(initialValue: workLog)
        self.workLogsViewModel = workLogsViewModel
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
                    Text(workLog.workDate.formatted(.dateTime.day().month().year()))
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 8) {
                        statusBadge
                        if workLog.isOvertime {
                            overtimeBadge
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Información") {
                LabeledContent("Horas", value: AppPreferences.formattedHours(workLog.hours, hourFormat: hourFormat))
                LabeledContent("Contrato", value: workLog.contract.name)
                LabeledContent("Cliente", value: workLog.contract.client.name)
                if let company = workLog.contract.client.company, !company.isEmpty {
                    LabeledContent("Empresa", value: company)
                }
                LabeledContent("Tarifa", value: "\(workLog.contract.hourlyRate) \(workLog.contract.currency)/h")
                LabeledContent("Horas extra", value: workLog.isOvertime ? "Sí" : "No")
                if let note = workLog.note, !note.isEmpty {
                    LabeledContent("Nota", value: note)
                }
                if let deletedAt = workLog.deletedAt {
                    LabeledContent("Archivado", value: deletedAt.formatted(.dateTime.day().month().year()))
                }
            }

            Section {
                Button {
                    isShowingEdit = true
                } label: {
                    Label("Editar", systemImage: "square.and.pencil")
                }

                Button(role: workLog.active ? .destructive : nil) {
                    if workLog.active {
                        if confirmBeforeArchive {
                            isShowingArchiveConfirmation = true
                        } else {
                            Task { await archive() }
                        }
                    } else {
                        isShowingReactivateConfirmation = true
                    }
                } label: {
                    if isUpdatingStatus {
                        ProgressView()
                    } else {
                        Label(workLog.active ? "Archivar registro" : "Reactivar registro", systemImage: workLog.active ? "archivebox" : "arrow.uturn.backward.circle")
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
        .navigationTitle("Registro")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refresh()
        }
        .refreshable {
            await refresh()
        }
        .sheet(isPresented: $isShowingEdit) {
            EditWorkLogView(workLog: workLog, workLogsViewModel: workLogsViewModel) { updatedWorkLog in
                workLog = updatedWorkLog
            }
            .environmentObject(authManager)
        }
        .confirmationDialog("¿Archivar registro?", isPresented: $isShowingArchiveConfirmation, titleVisibility: .visible) {
            Button("Archivar registro", role: .destructive) {
                Task {
                    await archive()
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Podrás reactivarlo más adelante.")
        }
        .confirmationDialog("¿Reactivar registro?", isPresented: $isShowingReactivateConfirmation, titleVisibility: .visible) {
            Button("Reactivar registro") {
                Task {
                    await reactivate()
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var statusBadge: some View {
        Text(workLog.active ? "Activo" : "Archivado")
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((workLog.active ? Color.green : Color.secondary).opacity(0.14), in: Capsule())
            .foregroundStyle(workLog.active ? .green : .secondary)
    }

    private var overtimeBadge: some View {
        Text("Horas extra")
            .font(.caption)
            .fontWeight(highlightOvertime ? .medium : .regular)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((highlightOvertime ? Color.orange : Color.secondary).opacity(0.14), in: Capsule())
            .foregroundStyle(highlightOvertime ? .orange : .secondary)
    }

    private func refresh() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            workLog = try await workLogsViewModel.fetchWorkLog(id: workLog.id, using: authManager)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func archive() async {
        errorMessage = nil
        isUpdatingStatus = true
        defer { isUpdatingStatus = false }

        do {
            workLog = try await workLogsViewModel.archive(workLog, using: authManager)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reactivate() async {
        errorMessage = nil
        isUpdatingStatus = true
        defer { isUpdatingStatus = false }

        do {
            workLog = try await workLogsViewModel.update(
                id: workLog.id,
                contractId: workLog.contractId,
                workDate: workLog.workDate,
                hours: workLog.hours,
                isOvertime: workLog.isOvertime,
                note: workLog.note,
                active: true,
                using: authManager
            )
        } catch {
            errorMessage = userFacingWorkLogError(error)
        }
    }
}
