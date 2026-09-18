import Foundation
import Combine

@MainActor
final class ClientsViewModel: ObservableObject {
    @Published var clients: [Client] = []
    @Published var includeInactive = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: ClientAPIService

    init() {
        self.service = ClientAPIService()
    }

    init(service: ClientAPIService) {
        self.service = service
    }

    var activeClients: [Client] {
        clients.filter(\.active)
    }

    var archivedClients: [Client] {
        clients.filter { !$0.active }
    }

    func load(using authManager: AuthManager) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            clients = try await service.getClients(includeInactive: includeInactive, token: requiredToken(from: authManager))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(name: String, email: String?, company: String?, using authManager: AuthManager) async throws -> Client {
        let client = try await service.createClient(
            name: name,
            email: email,
            company: company,
            token: requiredToken(from: authManager)
        )
        upsert(client)
        return client
    }

    func fetchClient(id: String, using authManager: AuthManager) async throws -> Client {
        try await service.getClient(clientId: id, token: requiredToken(from: authManager))
    }

    func update(
        clientId: String,
        name: String,
        email: String?,
        company: String?,
        active: Bool,
        using authManager: AuthManager
    ) async throws -> Client {
        let client = try await service.updateClient(
            clientId: clientId,
            name: name,
            email: email,
            company: company,
            active: active,
            token: requiredToken(from: authManager)
        )
        upsert(client)
        return client
    }

    func archive(_ client: Client, using authManager: AuthManager) async throws {
        try await service.archiveClient(clientId: client.id, token: requiredToken(from: authManager))
        if includeInactive {
            clients = try await service.getClients(includeInactive: true, token: requiredToken(from: authManager))
        } else {
            clients.removeAll { $0.id == client.id }
        }
    }

    private func upsert(_ client: Client) {
        if let index = clients.firstIndex(where: { $0.id == client.id }) {
            clients[index] = client
        } else if includeInactive || client.active {
            clients.insert(client, at: 0)
        }
    }

    private func requiredToken(from authManager: AuthManager) throws -> String {
        guard let token = authManager.token else {
            throw APIError.notAuthenticated
        }
        return token
    }
}
