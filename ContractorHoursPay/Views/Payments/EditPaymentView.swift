import SwiftUI

struct EditPaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject var paymentsViewModel: PaymentsViewModel

    let payment: Payment
    let onSaved: (Payment) -> Void

    @State private var amount: String
    @State private var paidAt: Date
    @State private var method: String
    @State private var note: String
    @State private var active: Bool
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(payment: Payment, paymentsViewModel: PaymentsViewModel, onSaved: @escaping (Payment) -> Void) {
        self.payment = payment
        self.paymentsViewModel = paymentsViewModel
        self.onSaved = onSaved
        _amount = State(initialValue: payment.amount)
        _paidAt = State(initialValue: payment.paidAt)
        _method = State(initialValue: payment.method ?? "")
        _note = State(initialValue: payment.note ?? "")
        _active = State(initialValue: payment.active)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Payment") {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    LabeledContent("Currency", value: payment.currency)
                    DatePicker("Paid Date", selection: $paidAt, displayedComponents: .date)
                    TextField("Method", text: $method)
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                    Toggle("Active", isOn: $active)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        isValidPositiveDecimal(amount) && !isLoading
    }

    private func save() async {
        errorMessage = nil
        guard canSave else {
            errorMessage = "Ingresá un pago válido."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let updated = try await paymentsViewModel.update(
                id: payment.id,
                amount: normalizedRate(amount),
                currency: payment.currency,
                paidAt: paidAt,
                method: normalizedOptional(method),
                note: normalizedOptional(note),
                active: active,
                using: authManager
            )
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = userFacingPaymentError(error)
        }
    }
}
