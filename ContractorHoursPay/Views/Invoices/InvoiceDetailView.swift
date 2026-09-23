import SwiftUI

struct InvoiceDetailView: View {
    @EnvironmentObject private var authManager: AuthManager
    @AppStorage(AppPreferenceKey.hideAmounts) private var hideAmounts = false
    @AppStorage(AppPreferenceKey.confirmBeforeArchive) private var confirmBeforeArchive = true
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

            Section("Resumen") {
                LabeledContent("Subtotal", value: money(invoice.subtotal))
                LabeledContent("Cobrado", value: money(invoice.paidAmount))
                LabeledContent("Saldo pendiente", value: money(invoice.outstandingAmount))
                LabeledContent("Moneda", value: invoice.currency)
                statusRow
            }
 
            Section("Período") {
                LabeledContent("Desde", value: invoice.periodFrom.formatted(.dateTime.day().month().year()))
                LabeledContent("Hasta", value: invoice.periodTo.formatted(.dateTime.day().month().year()))
                LabeledContent("Fecha de emisión", value: invoice.issuedAt.formatted(.dateTime.day().month().year()))
                if let dueDate = invoice.dueDate {
                    LabeledContent("Vence", value: dueDate.formatted(.dateTime.day().month().year()))
                }
            }

            Section("Cliente / Contrato") {
                LabeledContent("Cliente", value: invoice.client.name)
                if let company = invoice.client.company, !company.isEmpty {
                    LabeledContent("Empresa", value: company)
                }
                if let contract = invoice.contract {
                    LabeledContent("Contrato", value: contract.name)
                }
            }

            Section("Registros de horas") {
                if invoice.workLogs.isEmpty {
                    Text("No hay registros asociados.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(invoice.workLogs) { workLog in
                        InvoiceWorkLogRow(workLog: workLog)
                    }
                }
            }

            Section("Pagos") {
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
                        Label("Agregar pago", systemImage: "plus")
                    }
                }

                NavigationLink {
                    PaymentsView(invoiceId: invoice.id, preselectedInvoice: invoice)
                } label: {
                    Label("Ver todos", systemImage: "banknote")
                }
            }

            if let note = invoice.note, !note.isEmpty {
                Section("Nota") {
                    Text(note)
                }
            }

            Section {
                Button {
                    isShowingEdit = true
                } label: {
                    Label("Editar", systemImage: "square.and.pencil")
                }
                .disabled(!invoice.active)

                Button(role: invoice.active ? .destructive : nil) {
                    if invoice.active {
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
                        Label(invoice.active ? "Archivar factura" : "Reactivar factura", systemImage: invoice.active ? "archivebox" : "arrow.uturn.backward.circle")
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
        .navigationTitle("Factura")
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
        .confirmationDialog("¿Archivar factura?", isPresented: $isShowingArchiveConfirmation, titleVisibility: .visible) {
            Button("Archivar factura", role: .destructive) {
                Task { await archive() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Podrás reactivarla más adelante.")
        }
        .confirmationDialog("¿Reactivar factura?", isPresented: $isShowingReactivateConfirmation, titleVisibility: .visible) {
            Button("Reactivar factura") {
                Task { await reactivate() }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var canAddPayment: Bool {
        invoice.active
            && invoice.effectiveStatus != .cancelled
            && (decimalValue(invoice.outstandingAmount) ?? 0) > 0
    }

    private var statusRow: some View {
        HStack {
            Text("Estado")
            Spacer()
            Text(invoice.active ? invoice.effectiveStatus.title : "Archivada")
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
        AppPreferences.financialAmount(value, currency: invoice.currency, hideAmounts: hideAmounts)
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

private struct InvoiceWorkLogRow: View {
    @AppStorage(AppPreferenceKey.highlightOvertime) private var highlightOvertime = true
    @AppStorage(AppPreferenceKey.hourFormat) private var hourFormat = "decimal"

    let workLog: InvoiceWorkLogSummary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workLog.isOvertime ? "clock.badge.exclamationmark" : "clock")
                .font(.subheadline)
                .foregroundStyle(workLog.isOvertime && highlightOvertime ? .orange : .secondary)
                .frame(width: 32, height: 32)
                .background(iconBackground, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(workLog.workDate.formatted(.dateTime.day().month().year()))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let note = workLog.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(AppPreferences.formattedHours(workLog.hours, hourFormat: hourFormat))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if workLog.isOvertime {
                    Text("Horas extra")
                        .font(.caption2)
                        .fontWeight(highlightOvertime ? .semibold : .regular)
                        .foregroundStyle(highlightOvertime ? .orange : .secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var iconBackground: Color {
        if workLog.isOvertime && highlightOvertime {
            return Color.orange.opacity(0.14)
        }

        return Color(.tertiarySystemGroupedBackground)
    }
}
