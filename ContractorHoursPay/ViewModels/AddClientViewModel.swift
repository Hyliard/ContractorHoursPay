import Foundation
import Combine

@MainActor
final class AddClientViewModel: ObservableObject {
    @Published var name = ""
    @Published var email = ""
    @Published var company = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    func create(using authManager: AuthManager, clientsViewModel: ClientsViewModel) async -> Bool {
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = normalizedOptional(email)
        let trimmedCompany = normalizedOptional(company)

        guard !trimmedName.isEmpty else {
            errorMessage = "Ingresá el nombre del cliente."
            return false
        }

        guard isValidEmail(trimmedEmail) else {
            errorMessage = "Ingresá un email válido."
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await clientsViewModel.create(
                name: trimmedName,
                email: trimmedEmail,
                company: trimmedCompany,
                using: authManager
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

func normalizedOptional(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

func isValidEmail(_ email: String?) -> Bool {
    guard let email else {
        return true
    }

    let parts = email.split(separator: "@")
    guard parts.count == 2, let domain = parts.last else {
        return false
    }

    return domain.contains(".") && !email.contains(" ")
}
