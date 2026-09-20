import SwiftUI

struct EditInvoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject var invoicesViewModel: InvoicesViewModel

    let invoice: Invoice
    let onSaved: (Invoice) -> Void

    @State private var periodFrom: Date
    @State private var periodTo: Date
    @State private var subtotal: String
    @State private var issuedAt: Date
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var note: String
    @State private var status: InvoiceStatus
    @State private var active: Bool
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(invoice: Invoice, invoicesViewModel: InvoicesViewModel, onSaved: @escaping (Invoice) -> Void) {
        self.invoice = invoice
        self.invoicesViewModel = invoicesViewModel
        self.onSaved = onSaved
        _periodFrom = State(initialValue: invoice.periodFrom)
        _periodTo = State(initialValue: invoice.periodTo)
        _subtotal = State(initialValue: invoice.subtotal)
        _issuedAt = State(initialValue: invoice.issuedAt)
        _hasDueDate = State(initialValue: invoice.dueDate != nil)
        _dueDate = State(initialValue: invoice.dueDate ?? invoice.issuedAt)
        _note = State(initialValue: invoice.note ?? "")
        _status = State(initialValue: invoice.status)
        _active = State(initialValue: invoice.active)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Factura") {
                    TextField("Subtotal", text: $subtotal)
                        .keyboardType(.decimalPad)

                    Picker("Estado", selection: $status) {
                        ForEach(InvoiceStatus.allCases.filter { $0 != .overdue }) { status in
                            Text(status.title).tag(status)
                        }
                    }

                    Toggle("Activo", isOn: $active)
                }

                Section("Fechas") {
                    DatePicker("Desde", selection: $periodFrom, displayedComponents: .date)
                    DatePicker("Hasta", selection: $periodTo, displayedComponents: .date)
                    DatePicker("Fecha de emisión", selection: $issuedAt, displayedComponents: .date)
                    Toggle("Fecha de vencimiento", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Vence", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section("Nota") {
                    TextField("Opcional", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Editar factura")
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
        }
    }

    private var canSave: Bool {
        isValidPositiveDecimal(subtotal)
            && periodFrom.startOfBusinessDay <= periodTo.startOfBusinessDay
            && (!hasDueDate || dueDate.startOfBusinessDay >= issuedAt.startOfBusinessDay)
            && !isLoading
    }

    private func save() async {
        errorMessage = nil
        guard canSave else {
            errorMessage = "Revisá los datos de la factura."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let updated = try await invoicesViewModel.update(
                id: invoice.id,
                periodFrom: periodFrom,
                periodTo: periodTo,
                subtotal: normalizedRate(subtotal),
                issuedAt: issuedAt,
                dueDate: hasDueDate ? dueDate : nil,
                note: normalizedOptional(note),
                status: status,
                active: active,
                using: authManager
            )
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = userFacingInvoiceError(error)
        }
    }
}
