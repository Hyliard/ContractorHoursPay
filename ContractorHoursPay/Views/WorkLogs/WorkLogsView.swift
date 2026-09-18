import SwiftUI

struct WorkLogsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var viewModel: WorkLogsViewModel
    @State private var isShowingAddWorkLog = false

    private let preselectedContract: Contract?

    init(contractId: String? = nil, preselectedContract: Contract? = nil) {
        _viewModel = StateObject(wrappedValue: WorkLogsViewModel(contractId: contractId))
        self.preselectedContract = preselectedContract
    }

    var body: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            filtersSection

            if viewModel.includeInactive {
                activeSection
                archivedSection
            } else {
                activeRows
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.workLogs.isEmpty {
                ProgressView()
            } else if !viewModel.isLoading && viewModel.workLogs.isEmpty {
                ContentUnavailableView("Sin registros", systemImage: "clock.badge.questionmark")
            }
        }
        .navigationTitle("Horas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddWorkLog = true
                } label: {
                    Label("Nuevo registro", systemImage: "plus")
                }
                .disabled(preselectedContract?.active == false)
            }
        }
        .task {
            await viewModel.load(using: authManager)
        }
        .refreshable {
            await viewModel.load(using: authManager)
        }
        .onChange(of: viewModel.includeInactive) {
            Task { await viewModel.load(using: authManager) }
        }
        .onChange(of: viewModel.hasFromDate) {
            Task { await viewModel.load(using: authManager) }
        }
        .onChange(of: viewModel.fromDate) {
            if viewModel.hasFromDate {
                Task { await viewModel.load(using: authManager) }
            }
        }
        .onChange(of: viewModel.hasToDate) {
            Task { await viewModel.load(using: authManager) }
        }
        .onChange(of: viewModel.toDate) {
            if viewModel.hasToDate {
                Task { await viewModel.load(using: authManager) }
            }
        }
        .onChange(of: viewModel.overtimeFilter) {
            Task { await viewModel.load(using: authManager) }
        }
        .sheet(isPresented: $isShowingAddWorkLog) {
            AddWorkLogView(workLogsViewModel: viewModel, preselectedContract: preselectedContract)
                .environmentObject(authManager)
        }
    }

    private var filtersSection: some View {
        Section("Filtros") {
            Picker("Overtime", selection: $viewModel.overtimeFilter) {
                ForEach(WorkLogOvertimeFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }

            Toggle("Desde", isOn: $viewModel.hasFromDate)
            if viewModel.hasFromDate {
                DatePicker("Fecha desde", selection: $viewModel.fromDate, displayedComponents: .date)
            }

            Toggle("Hasta", isOn: $viewModel.hasToDate)
            if viewModel.hasToDate {
                DatePicker("Fecha hasta", selection: $viewModel.toDate, displayedComponents: .date)
            }

            Toggle("Ver archivados", isOn: $viewModel.includeInactive)
        }
    }

    private var activeRows: some View {
        ForEach(viewModel.activeWorkLogs) { workLog in
            NavigationLink {
                WorkLogDetailView(workLog: workLog, workLogsViewModel: viewModel)
            } label: {
                WorkLogRowView(workLog: workLog)
            }
        }
    }

    private var activeSection: some View {
        Section("Activos") {
            if viewModel.activeWorkLogs.isEmpty {
                Text("No hay registros activos.")
                    .foregroundStyle(.secondary)
            } else {
                activeRows
            }
        }
    }

    private var archivedSection: some View {
        Section("Archivados") {
            if viewModel.archivedWorkLogs.isEmpty {
                Text("No hay registros archivados.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.archivedWorkLogs) { workLog in
                    NavigationLink {
                        WorkLogDetailView(workLog: workLog, workLogsViewModel: viewModel)
                    } label: {
                        WorkLogRowView(workLog: workLog)
                    }
                }
            }
        }
    }
}
