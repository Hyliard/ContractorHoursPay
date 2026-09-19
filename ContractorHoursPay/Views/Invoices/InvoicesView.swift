import SwiftUI

struct InvoicesView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var viewModel: InvoicesViewModel
    @State private var isShowingAddInvoice = false

    private let preselectedClient: Client?
    private let preselectedContract: Contract?

    init(clientId: String? = nil, contractId: String? = nil, preselectedClient: Client? = nil, preselectedContract: Contract? = nil) {
        _viewModel = StateObject(wrappedValue: InvoicesViewModel(clientId: clientId, contractId: contractId))
        self.preselectedClient = preselectedClient
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
            if viewModel.isLoading && viewModel.invoices.isEmpty {
                ProgressView()
            } else if !viewModel.isLoading && viewModel.invoices.isEmpty {
                ContentUnavailableView("No tienes facturas todavía.", systemImage: "doc.text")
            }
        }
        .navigationTitle("Invoices")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddInvoice = true
                } label: {
                    Label("Nueva factura", systemImage: "plus")
                }
            }
        }
        .task {
            await viewModel.load(using: authManager)
        }
        .refreshable {
            await viewModel.load(using: authManager)
        }
        .onChange(of: viewModel.includeInactive) { Task { await viewModel.load(using: authManager) } }
        .onChange(of: viewModel.statusFilter) { Task { await viewModel.load(using: authManager) } }
        .onChange(of: viewModel.showOverdueOnly) { Task { await viewModel.load(using: authManager) } }
        .onChange(of: viewModel.hasFromDate) { Task { await viewModel.load(using: authManager) } }
        .onChange(of: viewModel.fromDate) {
            if viewModel.hasFromDate { Task { await viewModel.load(using: authManager) } }
        }
        .onChange(of: viewModel.hasToDate) { Task { await viewModel.load(using: authManager) } }
        .onChange(of: viewModel.toDate) {
            if viewModel.hasToDate { Task { await viewModel.load(using: authManager) } }
        }
        .sheet(isPresented: $isShowingAddInvoice) {
            AddInvoiceView(
                invoicesViewModel: viewModel,
                preselectedClient: preselectedClient,
                preselectedContract: preselectedContract
            )
            .environmentObject(authManager)
        }
    }

    private var filtersSection: some View {
        Section("Filters") {
            Picker("Status", selection: $viewModel.statusFilter) {
                Text("All").tag(Optional<InvoiceStatus>.none)
                ForEach(InvoiceStatus.allCases.filter { $0 != .overdue }) { status in
                    Text(status.title).tag(Optional(status))
                }
            }

            Toggle("Overdue only", isOn: $viewModel.showOverdueOnly)
            Toggle("From", isOn: $viewModel.hasFromDate)
            if viewModel.hasFromDate {
                DatePicker("From date", selection: $viewModel.fromDate, displayedComponents: .date)
            }
            Toggle("To", isOn: $viewModel.hasToDate)
            if viewModel.hasToDate {
                DatePicker("To date", selection: $viewModel.toDate, displayedComponents: .date)
            }
            Toggle("Include archived", isOn: $viewModel.includeInactive)
        }
    }

    private var activeRows: some View {
        ForEach(viewModel.activeInvoices) { invoice in
            NavigationLink {
                InvoiceDetailView(invoice: invoice, invoicesViewModel: viewModel)
            } label: {
                InvoiceRowView(invoice: invoice)
            }
        }
    }

    private var activeSection: some View {
        Section("Active") {
            if viewModel.activeInvoices.isEmpty {
                Text("No tienes facturas activas.")
                    .foregroundStyle(.secondary)
            } else {
                activeRows
            }
        }
    }

    private var archivedSection: some View {
        Section("Archived") {
            if viewModel.archivedInvoices.isEmpty {
                Text("No tienes facturas archivadas.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.archivedInvoices) { invoice in
                    NavigationLink {
                        InvoiceDetailView(invoice: invoice, invoicesViewModel: viewModel)
                    } label: {
                        InvoiceRowView(invoice: invoice)
                    }
                }
            }
        }
    }
}
