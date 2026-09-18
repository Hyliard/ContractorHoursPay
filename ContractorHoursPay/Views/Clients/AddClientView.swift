import SwiftUI

struct AddClientView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject var clientsViewModel: ClientsViewModel
    @StateObject private var viewModel = AddClientViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Cliente") {
                    TextField("Nombre", text: $viewModel.name)
                        .textContentType(.organizationName)

                    TextField("Email", text: $viewModel.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)

                    TextField("Empresa", text: $viewModel.company)
                        .textContentType(.organizationName)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Nuevo cliente")
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
                            if await viewModel.create(using: authManager, clientsViewModel: clientsViewModel) {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Guardar")
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
        }
    }
}
