import SwiftUI

struct DeleteAccountView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var viewModel = DeleteAccountViewModel()
    @State private var showingConfirmation = false

    var body: some View {
        Form {
            Section {
                Text("Esta acción elimina tu cuenta, tus dispositivos vinculados y cierra todas tus sesiones. No se puede deshacer.")
                    .foregroundStyle(.secondary)
            }

            Section("Confirmá tu contraseña") {
                SecureField("Contraseña", text: $viewModel.password)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(role: .destructive) {
                    showingConfirmation = true
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Eliminar cuenta")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .navigationTitle("Eliminar cuenta")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "¿Seguro que querés eliminar tu cuenta?",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Eliminar cuenta", role: .destructive) {
                Task {
                    _ = await viewModel.deleteAccount(using: authManager)
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }
}

#Preview {
    NavigationStack {
        DeleteAccountView()
            .environmentObject(AuthManager())
    }
}
