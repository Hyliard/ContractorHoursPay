import Foundation

struct ContractClientSummary: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let company: String?
}

struct Contract: Codable, Identifiable, Equatable {
    let id: String
    let clientId: String
    let name: String
    let hourlyRate: String
    let currency: String
    let overtimeRate: String?
    let active: Bool
    let startDate: Date?
    let endDate: Date?
    let createdAt: Date
    let updatedAt: Date
    let client: ContractClientSummary

    init(
        id: String,
        clientId: String,
        name: String,
        hourlyRate: String,
        currency: String,
        overtimeRate: String?,
        active: Bool,
        startDate: Date?,
        endDate: Date?,
        createdAt: Date,
        updatedAt: Date,
        client: ContractClientSummary
    ) {
        self.id = id
        self.clientId = clientId
        self.name = name
        self.hourlyRate = hourlyRate
        self.currency = currency
        self.overtimeRate = overtimeRate
        self.active = active
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.client = client
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        clientId = try container.decode(String.self, forKey: .clientId)
        name = try container.decode(String.self, forKey: .name)
        hourlyRate = try container.decode(String.self, forKey: .hourlyRate)
        currency = try container.decode(String.self, forKey: .currency)
        overtimeRate = try container.decodeIfPresent(String.self, forKey: .overtimeRate)
        active = try container.decode(Bool.self, forKey: .active)
        client = try container.decode(ContractClientSummary.self, forKey: .client)

        if let startDateValue = try container.decodeIfPresent(String.self, forKey: .startDate) {
            startDate = try Self.decodeDateOnly(startDateValue, forKey: .startDate)
        } else {
            startDate = nil
        }

        if let endDateValue = try container.decodeIfPresent(String.self, forKey: .endDate) {
            endDate = try Self.decodeDateOnly(endDateValue, forKey: .endDate)
        } else {
            endDate = nil
        }

        let createdAtValue = try container.decode(String.self, forKey: .createdAt)
        let updatedAtValue = try container.decode(String.self, forKey: .updatedAt)
        createdAt = try Self.decodeTimestamp(createdAtValue, forKey: .createdAt)
        updatedAt = try Self.decodeTimestamp(updatedAtValue, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(clientId, forKey: .clientId)
        try container.encode(name, forKey: .name)
        try container.encode(hourlyRate, forKey: .hourlyRate)
        try container.encode(currency, forKey: .currency)
        try container.encodeIfPresent(overtimeRate, forKey: .overtimeRate)
        try container.encode(active, forKey: .active)
        try container.encodeIfPresent(startDate.map(Self.encodeDateOnly), forKey: .startDate)
        try container.encodeIfPresent(endDate.map(Self.encodeDateOnly), forKey: .endDate)
        try container.encode(Self.encodeTimestamp(createdAt), forKey: .createdAt)
        try container.encode(Self.encodeTimestamp(updatedAt), forKey: .updatedAt)
        try container.encode(client, forKey: .client)
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
        case clientId
        case name
        case hourlyRate
        case currency
        case overtimeRate
        case active
        case startDate
        case endDate
        case createdAt
        case updatedAt
        case client
    }
}
