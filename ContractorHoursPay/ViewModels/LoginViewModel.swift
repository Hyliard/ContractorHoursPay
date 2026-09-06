import Foundation
import Combine
import UIKit

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var deviceName = UIDevice.current.name
    @Published var isLoading = false
    @Published var errorMessage: String?

    func login(using authManager: AuthManager) async -> Bool {
        errorMessage = nil
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Completá el email y la contraseña."
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await authManager.login(email: email, password: password, deviceName: deviceName)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
