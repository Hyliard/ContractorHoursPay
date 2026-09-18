import Foundation

struct WorkLogClientSummary: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let company: String?
}

struct WorkLogContractSummary: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let hourlyRate: String
    let currency: String
    let client: WorkLogClientSummary
}

struct WorkLog: Codable, Identifiable, Equatable {
    let id: String
    let contractId: String
    let workDate: Date
    let hours: String
    let isOvertime: Bool
    let note: String?
    let active: Bool
    let deletedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let contract: WorkLogContractSummary

    init(
        id: String,
        contractId: String,
        workDate: Date,
        hours: String,
        isOvertime: Bool,
        note: String?,
        active: Bool,
        deletedAt: Date?,
        createdAt: Date,
        updatedAt: Date,
        contract: WorkLogContractSummary
    ) {
        self.id = id
        self.contractId = contractId
        self.workDate = workDate
        self.hours = hours
        self.isOvertime = isOvertime
        self.note = note
        self.active = active
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.contract = contract
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        contractId = try container.decode(String.self, forKey: .contractId)
        hours = try container.decode(String.self, forKey: .hours)
        isOvertime = try container.decode(Bool.self, forKey: .isOvertime)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        active = try container.decode(Bool.self, forKey: .active)
        contract = try container.decode(WorkLogContractSummary.self, forKey: .contract)

        let workDateValue = try container.decode(String.self, forKey: .workDate)
        workDate = try Self.decodeDateOnly(workDateValue, forKey: .workDate)

        if let deletedAtValue = try container.decodeIfPresent(String.self, forKey: .deletedAt) {
            deletedAt = try Self.decodeTimestamp(deletedAtValue, forKey: .deletedAt)
        } else {
            deletedAt = nil
        }

        let createdAtValue = try container.decode(String.self, forKey: .createdAt)
        let updatedAtValue = try container.decode(String.self, forKey: .updatedAt)
        createdAt = try Self.decodeTimestamp(createdAtValue, forKey: .createdAt)
        updatedAt = try Self.decodeTimestamp(updatedAtValue, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(contractId, forKey: .contractId)
        try container.encode(Self.encodeDateOnly(workDate), forKey: .workDate)
        try container.encode(hours, forKey: .hours)
        try container.encode(isOvertime, forKey: .isOvertime)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(active, forKey: .active)
        try container.encodeIfPresent(deletedAt.map(Self.encodeTimestamp), forKey: .deletedAt)
        try container.encode(Self.encodeTimestamp(createdAt), forKey: .createdAt)
        try container.encode(Self.encodeTimestamp(updatedAt), forKey: .updatedAt)
        try container.encode(contract, forKey: .contract)
    }

    nonisolated static func encodeDateOnly(_ date: Date) -> String {
        makeDateOnlyFormatter().string(from: date)
    }

    private nonisolated static func decodeDateOnly(_ value: String, forKey key: CodingKeys) throws -> Date {
        if let date = makeDateOnlyFormatter().date(from: value) {
            return date
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [key], debugDescription: "Invalid date: \(value)")
        )
    }

    private nonisolated static func decodeTimestamp(_ value: String, forKey key: CodingKeys) throws -> Date {
        if let date = makeFractionalTimestampFormatter().date(from: value) ?? makeTimestampFormatter().date(from: value) {
            return date
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [key], debugDescription: "Invalid ISO 8601 timestamp: \(value)")
        )
    }

    private nonisolated static func encodeTimestamp(_ date: Date) -> String {
        makeFractionalTimestampFormatter().string(from: date)
    }

    private nonisolated static func makeDateOnlyFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private nonisolated static func makeFractionalTimestampFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private nonisolated static func makeTimestampFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case contractId
        case workDate
        case hours
        case isOvertime
        case note
        case active
        case deletedAt
        case createdAt
        case updatedAt
        case contract
    }
}
