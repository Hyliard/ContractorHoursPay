import Foundation

struct ClientAPIService {
    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func getClients(includeInactive: Bool = false, token: String) async throws -> [Client] {
        let path = includeInactive ? "api/clients?includeInactive=true" : "api/clients"
        let response: ClientListResponse = try await client.send(method: .get, path: path, token: token)
        return response.clients
    }

    func getClient(clientId: String, token: String) async throws -> Client {
        let response: ClientResponse = try await client.send(method: .get, path: "api/clients/\(clientId)", token: token)
        return response.client
    }

    func createClient(name: String, email: String?, company: String?, token: String) async throws -> Client {
        let body = ClientCreateRequest(name: name, email: email, company: company)
        let response: ClientResponse = try await client.send(method: .post, path: "api/clients", body: body, token: token)
        return response.client
    }

    func updateClient(
        clientId: String,
        name: String,
        email: String?,
        company: String?,
        active: Bool,
        token: String
    ) async throws -> Client {
        let body = ClientUpdateRequest(name: name, email: email, company: company, active: active)
        let response: ClientResponse = try await client.send(method: .patch, path: "api/clients/\(clientId)", body: body, token: token)
        return response.client
    }

    func archiveClient(clientId: String, token: String) async throws {
        try await client.sendNoContent(method: .delete, path: "api/clients/\(clientId)", token: token)
    }
}

private struct ClientCreateRequest: Encodable {
    let name: String
    let email: String?
    let company: String?
}

private struct ClientUpdateRequest: Encodable {
    let name: String
    let email: String?
    let company: String?
    let active: Bool
}

private struct ClientListResponse: Decodable {
    let clients: [Client]

    init(from decoder: Decoder) throws {
        if let clients = try? [Client](from: decoder) {
            self.clients = clients
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        clients = try container.decode([Client].self, forKey: .clients)
    }

    private enum CodingKeys: String, CodingKey {
        case clients
    }
}

private struct ClientResponse: Decodable {
    let client: Client

    init(from decoder: Decoder) throws {
        if let client = try? Client(from: decoder) {
            self.client = client
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        client = try container.decode(Client.self, forKey: .client)
    }

    private enum CodingKeys: String, CodingKey {
        case client
    }
}
