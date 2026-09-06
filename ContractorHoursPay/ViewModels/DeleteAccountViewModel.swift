import Foundation
import Combine

@MainActor
final class DeleteAccountViewModel: ObservableObject {
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    func deleteAccount(using authManager: AuthManager) async -> Bool {
        errorMessage = nil
        guard !password.isEmpty else {
            errorMessage = "Ingresá tu contraseña para confirmar."
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await authManager.deleteAccount(password: password)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
