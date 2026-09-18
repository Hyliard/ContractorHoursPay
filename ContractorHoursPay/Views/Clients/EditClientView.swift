import SwiftUI

struct EditClientView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject var clientsViewModel: ClientsViewModel

    let client: Client
    let onSaved: (Client) -> Void

    @State private var name: String
    @State private var email: String
    @State private var company: String
    @State private var active: Bool
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(client: Client, clientsViewModel: ClientsViewModel, onSaved: @escaping (Client) -> Void) {
        self.client = client
        self.clientsViewModel = clientsViewModel
        self.onSaved = onSaved
        _name = State(initialValue: client.name)
        _email = State(initialValue: client.email ?? "")
        _company = State(initialValue: client.company ?? "")
        _active = State(initialValue: client.active)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cliente") {
                    TextField("Nombre", text: $name)
                        .textContentType(.organizationName)

                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)

                    TextField("Empresa", text: $company)
                        .textContentType(.organizationName)

                    Toggle("Activo", isOn: $active)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Editar cliente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await save()
                        }
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
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    private func save() async {
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = normalizedOptional(email)
        let trimmedCompany = normalizedOptional(company)

        guard !trimmedName.isEmpty else {
            errorMessage = "Ingresá el nombre del cliente."
            return
        }

        guard isValidEmail(trimmedEmail) else {
            errorMessage = "Ingresá un email válido."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let updatedClient = try await clientsViewModel.update(
                clientId: client.id,
                name: trimmedName,
                email: trimmedEmail,
                company: trimmedCompany,
                active: active,
                using: authManager
            )
            onSaved(updatedClient)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
