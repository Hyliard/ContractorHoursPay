import Foundation
import Combine

enum WorkLogOvertimeFilter: String, CaseIterable, Identifiable {
    case all
    case overtime
    case regular

    var id: String { rawValue }

    var isOvertime: Bool? {
        switch self {
        case .all:
            return nil
        case .overtime:
            return true
        case .regular:
            return false
        }
    }

    var title: String {
        switch self {
        case .all:
            return "Todos"
        case .overtime:
            return "Horas extra"
        case .regular:
            return "Regular"
        }
    }
}

@MainActor
final class WorkLogsViewModel: ObservableObject {
    @Published var workLogs: [WorkLog] = []
    @Published var includeInactive = false
    @Published var hasFromDate = false
    @Published var fromDate = Date()
    @Published var hasToDate = false
    @Published var toDate = Date()
    @Published var overtimeFilter: WorkLogOvertimeFilter = .all
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: WorkLogAPIService
    private let contractId: String?

    init(contractId: String? = nil, includeInactive: Bool = false) {
        self.contractId = contractId
        self.includeInactive = includeInactive
        self.service = WorkLogAPIService()
    }

    init(contractId: String? = nil, includeInactive: Bool = false, service: WorkLogAPIService) {
        self.contractId = contractId
        self.includeInactive = includeInactive
        self.service = service
    }

    var activeWorkLogs: [WorkLog] {
        workLogs.filter(\.active)
    }

    var archivedWorkLogs: [WorkLog] {
        workLogs.filter { !$0.active }
    }

    func load(using authManager: AuthManager) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            workLogs = try await service.fetchWorkLogs(
                includeInactive: includeInactive,
                contractId: contractId,
                from: hasFromDate ? WorkLog.encodeDateOnly(fromDate) : nil,
                to: hasToDate ? WorkLog.encodeDateOnly(toDate) : nil,
                isOvertime: overtimeFilter.isOvertime,
                token: requiredToken(from: authManager)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchWorkLog(id: String, using authManager: AuthManager) async throws -> WorkLog {
        try await service.fetchWorkLog(id: id, token: requiredToken(from: authManager))
    }

    func create(
        contractId: String,
        workDate: Date,
        hours: String,
        isOvertime: Bool,
        note: String?,
        using authManager: AuthManager
    ) async throws -> WorkLog {
        let workLog = try await service.createWorkLog(
            contractId: contractId,
            workDate: WorkLog.encodeDateOnly(workDate),
            hours: hours,
            isOvertime: isOvertime,
            note: note,
            token: requiredToken(from: authManager)
        )
        upsert(workLog)
        return workLog
    }

    func update(
        id: String,
        contractId: String,
        workDate: Date,
        hours: String,
        isOvertime: Bool,
        note: String?,
        active: Bool,
        using authManager: AuthManager
    ) async throws -> WorkLog {
        let workLog = try await service.updateWorkLog(
            id: id,
            contractId: contractId,
            workDate: WorkLog.encodeDateOnly(workDate),
            hours: hours,
            isOvertime: isOvertime,
            note: note,
            active: active,
            token: requiredToken(from: authManager)
        )
        upsert(workLog)
        return workLog
    }

    func archive(_ workLog: WorkLog, using authManager: AuthManager) async throws -> WorkLog {
        let archived = try await service.archiveWorkLog(id: workLog.id, token: requiredToken(from: authManager))
        if includeInactive {
            upsert(archived)
        } else {
            workLogs.removeAll { $0.id == workLog.id }
        }
        return archived
    }

    private func upsert(_ workLog: WorkLog) {
        if let index = workLogs.firstIndex(where: { $0.id == workLog.id }) {
            workLogs[index] = workLog
        } else if includeInactive || workLog.active {
            workLogs.insert(workLog, at: 0)
        }
    }

    private func requiredToken(from authManager: AuthManager) throws -> String {
        guard let token = authManager.token else {
            throw APIError.notAuthenticated
        }
        return token
    }
}

func userFacingWorkLogError(_ error: Error) -> String {
    if case APIError.server(_, let statusCode) = error, statusCode == 409 {
        return "El contrato seleccionado no está activo. Elegí un contrato activo para registrar horas."
    }
    return error.localizedDescription
}
