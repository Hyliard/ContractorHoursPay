import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var viewModel = ChangePasswordViewModel()

    var body: some View {
        Form {
            Section("Contraseña actual") {
                SecureField("Contraseña actual", text: $viewModel.currentPassword)
            }

            Section("Contraseña nueva") {
                SecureField("Mínimo 8 caracteres", text: $viewModel.newPassword)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if let successMessage = viewModel.successMessage {
                Section {
                    Text(successMessage)
                        .foregroundStyle(.green)
                }
            }

            Section {
                Button {
                    Task {
                        await viewModel.submit(using: authManager)
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Actualizar contraseña")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isLoading)
            } footer: {
                Text("Al cambiar la contraseña se cierran todas tus sesiones activas, incluida esta. Vas a tener que volver a iniciar sesión.")
            }
        }
        .navigationTitle("Cambiar contraseña")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ChangePasswordView()
            .environmentObject(AuthManager())
    }
}
