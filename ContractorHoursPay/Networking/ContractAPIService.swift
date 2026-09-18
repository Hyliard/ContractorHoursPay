import Foundation

struct ContractAPIService {
    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func fetchContracts(includeInactive: Bool = false, clientId: String? = nil, token: String) async throws -> [Contract] {
        var queryItems: [String] = []
        if includeInactive {
            queryItems.append("includeInactive=true")
        }
        if let clientId {
            queryItems.append("clientId=\(clientId)")
        }

        let path = queryItems.isEmpty ? "api/contracts" : "api/contracts?\(queryItems.joined(separator: "&"))"
        let response: ContractListResponse = try await client.send(method: .get, path: path, token: token)
        return response.contracts
    }

    func fetchContract(id: String, token: String) async throws -> Contract {
        let response: ContractResponse = try await client.send(method: .get, path: "api/contracts/\(id)", token: token)
        return response.contract
    }

    func createContract(
        clientId: String,
        name: String,
        hourlyRate: String,
        currency: String,
        overtimeRate: String?,
        startDate: String?,
        endDate: String?,
        token: String
    ) async throws -> Contract {
        let body = ContractCreateRequest(
            clientId: clientId,
            name: name,
            hourlyRate: hourlyRate,
            currency: currency,
            overtimeRate: overtimeRate,
            startDate: startDate,
            endDate: endDate
        )
        let response: ContractResponse = try await client.send(method: .post, path: "api/contracts", body: body, token: token)
        return response.contract
    }

    func updateContract(
        id: String,
        clientId: String,
        name: String,
        hourlyRate: String,
        currency: String,
        overtimeRate: String?,
        active: Bool,
        startDate: String?,
        endDate: String?,
        token: String
    ) async throws -> Contract {
        let body = ContractUpdateRequest(
            clientId: clientId,
            name: name,
            hourlyRate: hourlyRate,
            currency: currency,
            overtimeRate: overtimeRate,
            active: active,
            startDate: startDate,
            endDate: endDate
        )
        let response: ContractResponse = try await client.send(method: .patch, path: "api/contracts/\(id)", body: body, token: token)
        return response.contract
    }

    func archiveContract(id: String, token: String) async throws -> Contract {
        let response: ContractResponse = try await client.send(method: .delete, path: "api/contracts/\(id)", token: token)
        return response.contract
    }
}

private struct ContractCreateRequest: Encodable {
    let clientId: String
    let name: String
    let hourlyRate: String
    let currency: String
    let overtimeRate: String?
    let startDate: String?
    let endDate: String?
}

private struct ContractUpdateRequest: Encodable {
    let clientId: String
    let name: String
    let hourlyRate: String
    let currency: String
    let overtimeRate: String?
    let active: Bool
    let startDate: String?
    let endDate: String?
}

private struct ContractListResponse: Decodable {
    let contracts: [Contract]

    init(from decoder: Decoder) throws {
        if let contracts = try? [Contract](from: decoder) {
            self.contracts = contracts
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        contracts = try container.decode([Contract].self, forKey: .contracts)
    }

    private enum CodingKeys: String, CodingKey {
        case contracts
    }
}

private struct ContractResponse: Decodable {
    let contract: Contract

    init(from decoder: Decoder) throws {
        if let contract = try? Contract(from: decoder) {
            self.contract = contract
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        contract = try container.decode(Contract.self, forKey: .contract)
    }

    private enum CodingKeys: String, CodingKey {
        case contract
    }
}
