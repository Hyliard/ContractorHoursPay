import SwiftUI

struct AddPaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @AppStorage(AppPreferenceKey.hideAmounts) private var hideAmounts = false
    @ObservedObject var paymentsViewModel: PaymentsViewModel

    let preselectedInvoice: Invoice?

    @State private var invoices: [Invoice] = []
    @State private var selectedInvoiceId = ""
    @State private var amount = ""
    @State private var currency = "USD"
    @State private var paidAt = Date()
    @State private var method = ""
    @State private var note = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let invoiceService = InvoiceAPIService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Pago") {
                    Picker("Factura", selection: $selectedInvoiceId) {
                        ForEach(invoices) { invoice in
                            Text("\(invoice.client.name) · \(AppPreferences.financialAmount(invoice.outstandingAmount, currency: invoice.currency, hideAmounts: hideAmounts))")
                                .tag(invoice.id)
                        }
                    }
                    .disabled(preselectedInvoice != nil)

                    if let selectedInvoice {
                        LabeledContent("Subtotal", value: AppPreferences.financialAmount(selectedInvoice.subtotal, currency: selectedInvoice.currency, hideAmounts: hideAmounts))
                        LabeledContent("Cobrado", value: AppPreferences.financialAmount(selectedInvoice.paidAmount, currency: selectedInvoice.currency, hideAmounts: hideAmounts))
                        LabeledContent("Saldo pendiente", value: AppPreferences.financialAmount(outstandingAmount, currency: selectedInvoice.currency, hideAmounts: hideAmounts))
                    }

                    TextField("Monto", text: $amount)
                        .keyboardType(.decimalPad)

                    TextField("Moneda", text: $currency)
                        .textInputAutocapitalization(.characters)
                        .disabled(preselectedInvoice != nil)

                    DatePicker("Fecha de pago", selection: $paidAt, displayedComponents: .date)

                    TextField("Método", text: $method)
                    TextField("Nota", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Nuevo pago")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
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
                await loadInvoices()
            }
            .onChange(of: selectedInvoiceId) {
                syncCurrencyFromSelection()
            }
        }
    }

    private var selectedInvoice: Invoice? {
        invoices.first { $0.id == selectedInvoiceId }
    }

    private var outstandingAmount: Decimal {
        guard let selectedInvoice else { return 0 }
        return decimalValue(selectedInvoice.outstandingAmount) ?? 0
    }

    private var canSave: Bool {
        guard let selectedInvoice,
              isValidPositiveDecimal(amount),
              isValidCurrencyCode(currency),
              let paymentAmount = decimalValue(amount) else {
            return false
        }

        return selectedInvoice.active
            && selectedInvoice.effectiveStatus != .cancelled
            && selectedInvoice.currency == currency.uppercased()
            && paymentAmount <= outstandingAmount
            && !isLoading
    }

    private func loadInvoices() async {
        errorMessage = nil
        do {
            guard let token = authManager.token else { throw APIError.notAuthenticated }
            invoices = try await invoiceService.fetchInvoices(includeInactive: false, token: token)
                .filter { $0.effectiveStatus != .cancelled && (decimalValue($0.outstandingAmount) ?? 0) > 0 }

            if let preselectedInvoice {
                selectedInvoiceId = preselectedInvoice.id
                currency = preselectedInvoice.currency
                if !invoices.contains(where: { $0.id == preselectedInvoice.id }) {
                    invoices.insert(preselectedInvoice, at: 0)
                }
            } else if selectedInvoiceId.isEmpty {
                selectedInvoiceId = invoices.first?.id ?? ""
                syncCurrencyFromSelection()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncCurrencyFromSelection() {
        if let selectedInvoice {
            currency = selectedInvoice.currency
        }
    }

    private func save() async {
        errorMessage = nil
        guard canSave else {
            errorMessage = "El pago debe ser válido y no superar el saldo pendiente."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await paymentsViewModel.create(
                invoiceId: selectedInvoiceId,
                amount: normalizedRate(amount),
                currency: currency.uppercased(),
                paidAt: paidAt,
                method: normalizedOptional(method),
                note: normalizedOptional(note),
                using: authManager
            )
            dismiss()
        } catch {
            errorMessage = userFacingPaymentError(error)
        }
    }
}
