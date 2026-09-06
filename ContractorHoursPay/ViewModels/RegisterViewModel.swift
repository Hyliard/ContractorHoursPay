import Foundation
import Combine

@MainActor
final class RegisterViewModel: ObservableObject {
    @Published var name = ""
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var didRegister = false

    func register(using authManager: AuthManager) async {
        errorMessage = nil
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMessage = "Todos los campos son obligatorios."
            return
        }
        guard password.count >= 8 else {
            errorMessage = "La contraseña debe tener al menos 8 caracteres."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await authManager.register(name: name, email: email, password: password)
            didRegister = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
