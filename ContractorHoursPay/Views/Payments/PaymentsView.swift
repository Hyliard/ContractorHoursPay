import SwiftUI

struct PaymentsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var viewModel: PaymentsViewModel
    @State private var isShowingAddPayment = false

    private let preselectedInvoice: Invoice?

    init(invoiceId: String? = nil, clientId: String? = nil, preselectedInvoice: Invoice? = nil) {
        _viewModel = StateObject(wrappedValue: PaymentsViewModel(invoiceId: invoiceId, clientId: clientId))
        self.preselectedInvoice = preselectedInvoice
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
            if viewModel.isLoading && viewModel.payments.isEmpty {
                ProgressView()
            } else if !viewModel.isLoading && viewModel.payments.isEmpty {
                ContentUnavailableView("No tienes pagos registrados.", systemImage: "banknote")
            }
        }
        .navigationTitle("Pagos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddPayment = true
                } label: {
                    Label("Nuevo pago", systemImage: "plus")
                }
                .disabled(preselectedInvoice?.active == false || preselectedInvoice?.effectiveStatus == .cancelled)
            }
        }
        .task {
            await viewModel.load(using: authManager)
        }
        .refreshable {
            await viewModel.load(using: authManager)
        }
        .onChange(of: viewModel.includeInactive) { Task { await viewModel.load(using: authManager) } }
        .onChange(of: viewModel.hasFromDate) { Task { await viewModel.load(using: authManager) } }
        .onChange(of: viewModel.fromDate) {
            if viewModel.hasFromDate { Task { await viewModel.load(using: authManager) } }
        }
        .onChange(of: viewModel.hasToDate) { Task { await viewModel.load(using: authManager) } }
        .onChange(of: viewModel.toDate) {
            if viewModel.hasToDate { Task { await viewModel.load(using: authManager) } }
        }
        .sheet(isPresented: $isShowingAddPayment) {
            AddPaymentView(paymentsViewModel: viewModel, preselectedInvoice: preselectedInvoice)
                .environmentObject(authManager)
        }
    }

    private var filtersSection: some View {
        Section("Filtros") {
            Toggle("Desde", isOn: $viewModel.hasFromDate)
            if viewModel.hasFromDate {
                DatePicker("Fecha desde", selection: $viewModel.fromDate, displayedComponents: .date)
            }
            Toggle("Hasta", isOn: $viewModel.hasToDate)
            if viewModel.hasToDate {
                DatePicker("Fecha hasta", selection: $viewModel.toDate, displayedComponents: .date)
            }
            Toggle("Incluir archivados", isOn: $viewModel.includeInactive)
        }
    }

    private var activeRows: some View {
        ForEach(viewModel.activePayments) { payment in
            NavigationLink {
                PaymentDetailView(payment: payment, paymentsViewModel: viewModel)
            } label: {
                PaymentRowView(payment: payment)
            }
        }
    }

    private var activeSection: some View {
        Section("Activos") {
            if viewModel.activePayments.isEmpty {
                Text("No tienes pagos activos.")
                    .foregroundStyle(.secondary)
            } else {
                activeRows
            }
        }
    }

    private var archivedSection: some View {
        Section("Archivados") {
            if viewModel.archivedPayments.isEmpty {
                Text("No tienes pagos archivados.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.archivedPayments) { payment in
                    NavigationLink {
                        PaymentDetailView(payment: payment, paymentsViewModel: viewModel)
                    } label: {
                        PaymentRowView(payment: payment)
                    }
                }
            }
        }
    }
}
