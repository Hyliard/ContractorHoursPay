import Foundation

struct WorkLogAPIService {
    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func fetchWorkLogs(
        includeInactive: Bool = false,
        contractId: String? = nil,
        from: String? = nil,
        to: String? = nil,
        isOvertime: Bool? = nil,
        token: String
    ) async throws -> [WorkLog] {
        var queryItems: [String] = []
        if includeInactive {
            queryItems.append("includeInactive=true")
        }
        if let contractId {
            queryItems.append("contractId=\(contractId)")
        }
        if let from {
            queryItems.append("from=\(from)")
        }
        if let to {
            queryItems.append("to=\(to)")
        }
        if let isOvertime {
            queryItems.append("isOvertime=\(isOvertime)")
        }

        let path = queryItems.isEmpty ? "api/worklogs" : "api/worklogs?\(queryItems.joined(separator: "&"))"
        let response: WorkLogListResponse = try await client.send(method: .get, path: path, token: token)
        return response.workLogs
    }

    func fetchWorkLog(id: String, token: String) async throws -> WorkLog {
        let response: WorkLogResponse = try await client.send(method: .get, path: "api/worklogs/\(id)", token: token)
        return response.workLog
    }

    func createWorkLog(
        contractId: String,
        workDate: String,
        hours: String,
        isOvertime: Bool,
        note: String?,
        token: String
    ) async throws -> WorkLog {
        let body = WorkLogCreateRequest(
            contractId: contractId,
            workDate: workDate,
            hours: hours,
            isOvertime: isOvertime,
            note: note
        )
        let response: WorkLogResponse = try await client.send(method: .post, path: "api/worklogs", body: body, token: token)
        return response.workLog
    }

    func updateWorkLog(
        id: String,
        contractId: String,
        workDate: String,
        hours: String,
        isOvertime: Bool,
        note: String?,
        active: Bool,
        token: String
    ) async throws -> WorkLog {
        let body = WorkLogUpdateRequest(
            contractId: contractId,
            workDate: workDate,
            hours: hours,
            isOvertime: isOvertime,
            note: note,
            active: active
        )
        let response: WorkLogResponse = try await client.send(method: .patch, path: "api/worklogs/\(id)", body: body, token: token)
        return response.workLog
    }

    func archiveWorkLog(id: String, token: String) async throws -> WorkLog {
        let response: WorkLogResponse = try await client.send(method: .delete, path: "api/worklogs/\(id)", token: token)
        return response.workLog
    }
}

private struct WorkLogCreateRequest: Encodable {
    let contractId: String
    let workDate: String
    let hours: String
    let isOvertime: Bool
    let note: String?
}

private struct WorkLogUpdateRequest: Encodable {
    let contractId: String
    let workDate: String
    let hours: String
    let isOvertime: Bool
    let note: String?
    let active: Bool
}

private struct WorkLogListResponse: Decodable {
    let workLogs: [WorkLog]

    init(from decoder: Decoder) throws {
        if let workLogs = try? [WorkLog](from: decoder) {
            self.workLogs = workLogs
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        workLogs = try container.decode([WorkLog].self, forKey: .workLogs)
    }

    private enum CodingKeys: String, CodingKey {
        case workLogs
    }
}

private struct WorkLogResponse: Decodable {
    let workLog: WorkLog

    init(from decoder: Decoder) throws {
        if let workLog = try? WorkLog(from: decoder) {
            self.workLog = workLog
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        workLog = try container.decode(WorkLog.self, forKey: .workLog)
    }

    private enum CodingKeys: String, CodingKey {
        case workLog
    }
}
