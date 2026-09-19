import SwiftUI

struct InvoiceDetailView: View {
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject var invoicesViewModel: InvoicesViewModel
    @StateObject private var paymentsViewModel: PaymentsViewModel

    @State private var invoice: Invoice
    @State private var isLoading = false
    @State private var isUpdatingStatus = false
    @State private var errorMessage: String?
    @State private var isShowingEdit = false
    @State private var isShowingAddPayment = false
    @State private var isShowingArchiveConfirmation = false
    @State private var isShowingReactivateConfirmation = false

    init(invoice: Invoice, invoicesViewModel: InvoicesViewModel) {
        _invoice = State(initialValue: invoice)
        _paymentsViewModel = StateObject(wrappedValue: PaymentsViewModel(invoiceId: invoice.id, includeInactive: true))
        self.invoicesViewModel = invoicesViewModel
    }

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section("Summary") {
                LabeledContent("Subtotal", value: money(invoice.subtotal))
                LabeledContent("Paid", value: money(invoice.paidAmount))
                LabeledContent("Outstanding", value: money(invoice.outstandingAmount))
                LabeledContent("Currency", value: invoice.currency)
                statusRow
            }
 
            Section("Period") {
                LabeledContent("From", value: invoice.periodFrom.formatted(.dateTime.day().month().year()))
                LabeledContent("To", value: invoice.periodTo.formatted(.dateTime.day().month().year()))
                LabeledContent("Issued", value: invoice.issuedAt.formatted(.dateTime.day().month().year()))
                if let dueDate = invoice.dueDate {
                    LabeledContent("Due", value: dueDate.formatted(.dateTime.day().month().year()))
                }
            }

            Section("Client / Contract") {
                LabeledContent("Client", value: invoice.client.name)
                if let company = invoice.client.company, !company.isEmpty {
                    LabeledContent("Company", value: company)
                }
                if let contract = invoice.contract {
                    LabeledContent("Contract", value: contract.name)
                }
            }

            Section("WorkLogs") {
                if invoice.workLogs.isEmpty {
                    Text("No hay registros asociados.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(invoice.workLogs) { workLog in
                        WorkLogRowView(workLog: workLog)
                    }
                }
            }

            Section("Payments") {
                if paymentsViewModel.isLoading && paymentsViewModel.payments.isEmpty {
                    ProgressView()
                } else if paymentsViewModel.payments.isEmpty {
                    Text("No hay pagos para esta factura.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(paymentsViewModel.payments.prefix(5)) { payment in
                        NavigationLink {
                            PaymentDetailView(payment: payment, paymentsViewModel: paymentsViewModel) {
                                Task { await refreshAll() }
                            }
                        } label: {
                            PaymentRowView(payment: payment)
                        }
                    }
                }

                if canAddPayment {
                    Button {
                        isShowingAddPayment = true
                    } label: {
                        Label("Add Payment", systemImage: "plus")
                    }
                }

                NavigationLink {
                    PaymentsView(invoiceId: invoice.id, preselectedInvoice: invoice)
                } label: {
                    Label("View all", systemImage: "banknote")
                }
            }

            if let note = invoice.note, !note.isEmpty {
                Section("Note") {
                    Text(note)
                }
            }

            Section {
                Button {
                    isShowingEdit = true
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }
                .disabled(!invoice.active)

                Button(role: invoice.active ? .destructive : nil) {
                    if invoice.active {
                        isShowingArchiveConfirmation = true
                    } else {
                        isShowingReactivateConfirmation = true
                    }
                } label: {
                    if isUpdatingStatus {
                        ProgressView()
                    } else {
                        Label(invoice.active ? "Archive Invoice" : "Reactivate Invoice", systemImage: invoice.active ? "archivebox" : "arrow.uturn.backward.circle")
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
        .navigationTitle("Invoice")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshAll()
        }
        .refreshable {
            await refreshAll()
        }
        .sheet(isPresented: $isShowingEdit) {
            EditInvoiceView(invoice: invoice, invoicesViewModel: invoicesViewModel) { updatedInvoice in
                invoice = updatedInvoice
            }
            .environmentObject(authManager)
        }
        .sheet(isPresented: $isShowingAddPayment, onDismiss: {
            Task { await refreshAll() }
        }) {
            AddPaymentView(paymentsViewModel: paymentsViewModel, preselectedInvoice: invoice)
                .environmentObject(authManager)
        }
        .confirmationDialog("Archive Invoice?", isPresented: $isShowingArchiveConfirmation, titleVisibility: .visible) {
            Button("Archive Invoice", role: .destructive) {
                Task { await archive() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The invoice will be hidden from active lists, but it will not be permanently deleted.")
        }
        .confirmationDialog("Reactivate Invoice?", isPresented: $isShowingReactivateConfirmation, titleVisibility: .visible) {
            Button("Reactivate Invoice") {
                Task { await reactivate() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var canAddPayment: Bool {
        invoice.active
            && invoice.effectiveStatus != .cancelled
            && (decimalValue(invoice.outstandingAmount) ?? 0) > 0
    }

    private var statusRow: some View {
        HStack {
            Text("Status")
            Spacer()
            Text(invoice.active ? invoice.effectiveStatus.title : "Archived")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.14), in: Capsule())
                .foregroundStyle(statusColor)
        }
    }

    private var statusColor: Color {
        if !invoice.active { return .secondary }
        switch invoice.effectiveStatus {
        case .draft: return .secondary
        case .pending: return .orange
        case .paid: return .green
        case .cancelled: return .secondary
        case .overdue: return .red
        }
    }

    private func money(_ value: String) -> String {
        (decimalValue(value) ?? 0).formattedCurrency(code: invoice.currency)
    }

    private func refreshAll() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            invoice = try await invoicesViewModel.fetchInvoice(id: invoice.id, using: authManager)
            await paymentsViewModel.load(using: authManager)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func archive() async {
        errorMessage = nil
        isUpdatingStatus = true
        defer { isUpdatingStatus = false }

        do {
            invoice = try await invoicesViewModel.archive(invoice, using: authManager)
        } catch {
            errorMessage = userFacingInvoiceError(error)
        }
    }

    private func reactivate() async {
        errorMessage = nil
        isUpdatingStatus = true
        defer { isUpdatingStatus = false }

        do {
            invoice = try await invoicesViewModel.reactivate(invoice, using: authManager)
        } catch {
            errorMessage = userFacingInvoiceError(error)
        }
    }
}
