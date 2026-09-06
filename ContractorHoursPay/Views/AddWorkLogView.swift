import SwiftUI

struct AddWorkLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedClient = ContractorDashboardMock.clients[0]
    @State private var date = Date()
    @State private var hours = 8.0
    @State private var hourlyRate = 30.0
    @State private var currency = "USD"
    @State private var note = ""
    @State private var showingSavedConfirmation = false

    private let clients = ContractorDashboardMock.clients
    private let currencies = ["USD", "ARS", "EUR"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Trabajo") {
                    Picker("Cliente", selection: $selectedClient) {
                        ForEach(clients) { client in
                            Text(client.name)
                                .tag(client)
                        }
                    }

                    DatePicker("Fecha", selection: $date, displayedComponents: .date)

                    Stepper(value: $hours, in: 0.5...24, step: 0.5) {
                        LabeledContent("Horas", value: hours.formatted(.number.precision(.fractionLength(1))))
                    }
                }

                Section("Tarifa") {
                    Stepper(value: $hourlyRate, in: 1...500, step: 1) {
                        LabeledContent("Tarifa", value: hourlyRate.formatted(.number.precision(.fractionLength(0))))
                    }

                    Picker("Moneda", selection: $currency) {
                        ForEach(currencies, id: \.self) { currency in
                            Text(currency)
                        }
                    }
                }

                Section("Nota") {
                    TextField("Opcional", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section {
                    Button {
                        showingSavedConfirmation = true
                    } label: {
                        Label("Guardar registro", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                } footer: {
                    Text("Este registro es local por ahora. La integración con la API se agregará en una fase posterior.")
                }
            }
            .navigationTitle("Registrar horas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
            .alert("Registro guardado", isPresented: $showingSavedConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("El flujo visual quedó registrado localmente.")
            }
        }
    }
}

#Preview {
    AddWorkLogView()
}
