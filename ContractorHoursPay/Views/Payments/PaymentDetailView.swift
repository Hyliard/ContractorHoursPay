import SwiftUI

struct PaymentDetailView: View {
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject var paymentsViewModel: PaymentsViewModel

    @State private var payment: Payment
    @State private var isLoading = false
    @State private var isUpdatingStatus = false
    @State private var errorMessage: String?
    @State private var isShowingEdit = false
    @State private var isShowingArchiveConfirmation = false
    @State private var isShowingReactivateConfirmation = false

    let onPaymentChanged: (() -> Void)?

    init(payment: Payment, paymentsViewModel: PaymentsViewModel, onPaymentChanged: (() -> Void)? = nil) {
        _payment = State(initialValue: payment)
        self.paymentsViewModel = paymentsViewModel
        self.onPaymentChanged = onPaymentChanged
    }

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section("Payment") {
                LabeledContent("Amount", value: money(payment.amount))
                LabeledContent("Currency", value: payment.currency)
                LabeledContent("Paid At", value: payment.paidAt.formatted(.dateTime.day().month().year()))
                if let method = payment.method, !method.isEmpty {
                    LabeledContent("Method", value: method)
                }
                statusRow
            }

            Section("Invoice") {
                LabeledContent("Client", value: payment.client.name)
                LabeledContent("Subtotal", value: invoiceMoney(payment.invoice.subtotal))
                if let paidAmount = payment.invoice.paidAmount {
                    LabeledContent("Paid", value: invoiceMoney(paidAmount))
                }
                if let outstandingAmount = payment.invoice.outstandingAmount {
                    LabeledContent("Outstanding", value: invoiceMoney(outstandingAmount))
                }
                LabeledContent("Invoice Status", value: invoiceStatusTitle)
            }

            if let note = payment.note, !note.isEmpty {
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
                .disabled(!payment.active)

                Button(role: payment.active ? .destructive : nil) {
                    if payment.active {
                        isShowingArchiveConfirmation = true
                    } else {
                        isShowingReactivateConfirmation = true
                    }
                } label: {
                    if isUpdatingStatus {
                        ProgressView()
                    } else {
                        Label(payment.active ? "Archive Payment" : "Reactivate Payment", systemImage: payment.active ? "archivebox" : "arrow.uturn.backward.circle")
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
        .navigationTitle("Payment")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refresh()
        }
        .refreshable {
            await refresh()
        }
        .sheet(isPresented: $isShowingEdit) {
            EditPaymentView(payment: payment, paymentsViewModel: paymentsViewModel) { updatedPayment in
                payment = updatedPayment
                onPaymentChanged?()
            }
            .environmentObject(authManager)
        }
        .confirmationDialog("Archive Payment?", isPresented: $isShowingArchiveConfirmation, titleVisibility: .visible) {
            Button("Archive Payment", role: .destructive) {
                Task { await archive() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The payment will be hidden from active lists, but it will not be permanently deleted.")
        }
        .confirmationDialog("Reactivate Payment?", isPresented: $isShowingReactivateConfirmation, titleVisibility: .visible) {
            Button("Reactivate Payment") {
                Task { await reactivate() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var statusRow: some View {
        HStack {
            Text("Status")
            Spacer()
            Text(payment.active ? "Active" : "Archived")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((payment.active ? Color.green : Color.secondary).opacity(0.14), in: Capsule())
                .foregroundStyle(payment.active ? .green : .secondary)
        }
    }

    private func money(_ value: String) -> String {
        (decimalValue(value) ?? 0).formattedCurrency(code: payment.currency)
    }

    private func invoiceMoney(_ value: String) -> String {
        (decimalValue(value) ?? 0).formattedCurrency(code: payment.invoice.currency)
    }

    private var invoiceStatusTitle: String {
        (payment.invoice.effectiveStatus ?? payment.invoice.status).title
    }

    private func refresh() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            payment = try await paymentsViewModel.fetchPayment(id: payment.id, using: authManager)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func archive() async {
        errorMessage = nil
        isUpdatingStatus = true
        defer { isUpdatingStatus = false }

        do {
            payment = try await paymentsViewModel.archive(payment, using: authManager)
            onPaymentChanged?()
        } catch {
            errorMessage = userFacingPaymentError(error)
        }
    }

    private func reactivate() async {
        errorMessage = nil
        isUpdatingStatus = true
        defer { isUpdatingStatus = false }

        do {
            payment = try await paymentsViewModel.reactivate(payment, using: authManager)
            onPaymentChanged?()
        } catch {
            errorMessage = userFacingPaymentError(error)
        }
    }
}
