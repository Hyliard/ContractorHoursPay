import Foundation

struct Client: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let name: String
    let email: String?
    let company: String?
    let active: Bool
    let createdAt: Date
    let updatedAt: Date

    init(
        id: String,
        userId: String,
        name: String,
        email: String?,
        company: String?,
        active: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.email = email
        self.company = company
        self.active = active
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        company = try container.decodeIfPresent(String.self, forKey: .company)
        active = try container.decode(Bool.self, forKey: .active)

        let createdAtValue = try container.decode(String.self, forKey: .createdAt)
        let updatedAtValue = try container.decode(String.self, forKey: .updatedAt)
        createdAt = try Self.decodeDate(createdAtValue, forKey: .createdAt)
        updatedAt = try Self.decodeDate(updatedAtValue, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(company, forKey: .company)
        try container.encode(active, forKey: .active)
        try container.encode(Self.encodeDate(createdAt), forKey: .createdAt)
        try container.encode(Self.encodeDate(updatedAt), forKey: .updatedAt)
    }

    private static func decodeDate(_ value: String, forKey key: CodingKeys) throws -> Date {
        if let date = fractionalDateFormatter.date(from: value) ?? dateFormatter.date(from: value) {
            return date
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: [key],
                debugDescription: "Invalid ISO 8601 date: \(value)"
            )
        )
    }

    private static func encodeDate(_ date: Date) -> String {
        fractionalDateFormatter.string(from: date)
    }

    private static let fractionalDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private enum CodingKeys: String, CodingKey {
        case id
        case userId
        case name
        case email
        case company
        case active
        case createdAt
        case updatedAt
    }
}
