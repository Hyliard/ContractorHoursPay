import Foundation
import Combine

@MainActor
final class ChangePasswordViewModel: ObservableObject {
    @Published var currentPassword = ""
    @Published var newPassword = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func submit(using authManager: AuthManager) async {
        errorMessage = nil
        successMessage = nil
        guard !currentPassword.isEmpty, !newPassword.isEmpty else {
            errorMessage = "Completá ambos campos."
            return
        }
        guard newPassword.count >= 8 else {
            errorMessage = "La nueva contraseña debe tener al menos 8 caracteres."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            successMessage = try await authManager.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
