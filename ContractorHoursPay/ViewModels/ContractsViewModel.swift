import Foundation
import Combine

@MainActor
final class ContractsViewModel: ObservableObject {
    @Published var contracts: [Contract] = []
    @Published var includeInactive = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: ContractAPIService
    private let clientId: String?

    init(clientId: String? = nil, includeInactive: Bool = false) {
        self.clientId = clientId
        self.includeInactive = includeInactive
        self.service = ContractAPIService()
    }

    init(clientId: String? = nil, includeInactive: Bool = false, service: ContractAPIService) {
        self.clientId = clientId
        self.includeInactive = includeInactive
        self.service = service
    }

    var activeContracts: [Contract] {
        contracts.filter(\.active)
    }

    var archivedContracts: [Contract] {
        contracts.filter { !$0.active }
    }

    func load(using authManager: AuthManager) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            contracts = try await service.fetchContracts(
                includeInactive: includeInactive,
                clientId: clientId,
                token: requiredToken(from: authManager)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchContract(id: String, using authManager: AuthManager) async throws -> Contract {
        try await service.fetchContract(id: id, token: requiredToken(from: authManager))
    }

    func create(
        clientId: String,
        name: String,
        hourlyRate: String,
        currency: String,
        overtimeRate: String?,
        startDate: Date?,
        endDate: Date?,
        using authManager: AuthManager
    ) async throws -> Contract {
        let contract = try await service.createContract(
            clientId: clientId,
            name: name,
            hourlyRate: hourlyRate,
            currency: currency,
            overtimeRate: overtimeRate,
            startDate: startDate.map(Contract.encodeDateOnly),
            endDate: endDate.map(Contract.encodeDateOnly),
            token: requiredToken(from: authManager)
        )
        upsert(contract)
        return contract
    }

    func update(
        id: String,
        clientId: String,
        name: String,
        hourlyRate: String,
        currency: String,
        overtimeRate: String?,
        active: Bool,
        startDate: Date?,
        endDate: Date?,
        using authManager: AuthManager
    ) async throws -> Contract {
        let contract = try await service.updateContract(
            id: id,
            clientId: clientId,
            name: name,
            hourlyRate: hourlyRate,
            currency: currency,
            overtimeRate: overtimeRate,
            active: active,
            startDate: startDate.map(Contract.encodeDateOnly),
            endDate: endDate.map(Contract.encodeDateOnly),
            token: requiredToken(from: authManager)
        )
        upsert(contract)
        return contract
    }

    func archive(_ contract: Contract, using authManager: AuthManager) async throws -> Contract {
        let archived = try await service.archiveContract(id: contract.id, token: requiredToken(from: authManager))
        if includeInactive {
            upsert(archived)
        } else {
            contracts.removeAll { $0.id == contract.id }
        }
        return archived
    }

    private func upsert(_ contract: Contract) {
        if let index = contracts.firstIndex(where: { $0.id == contract.id }) {
            contracts[index] = contract
        } else if includeInactive || contract.active {
            contracts.insert(contract, at: 0)
        }
    }

    private func requiredToken(from authManager: AuthManager) throws -> String {
        guard let token = authManager.token else {
            throw APIError.notAuthenticated
        }
        return token
    }
}

func normalizedRate(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
}

func isValidPositiveDecimal(_ value: String) -> Bool {
    let normalized = normalizedRate(value)
    guard !normalized.isEmpty,
          normalized.range(of: #"^\d+(\.\d{1,4})?$"#, options: .regularExpression) != nil,
          let decimal = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
        return false
    }
    return decimal > 0
}

func userFacingError(_ error: Error) -> String {
    if case APIError.server(_, let statusCode) = error, statusCode == 409 {
        return "El cliente seleccionado no está activo. Elegí un cliente activo para este contrato."
    }
    return error.localizedDescription
}
