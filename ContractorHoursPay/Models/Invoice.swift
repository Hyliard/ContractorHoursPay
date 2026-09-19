import Foundation

enum InvoiceStatus: String, Codable, CaseIterable, Identifiable {
    case draft = "DRAFT"
    case pending = "PENDING"
    case paid = "PAID"
    case cancelled = "CANCELLED"
    case overdue = "OVERDUE"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .draft: "Draft"
        case .pending: "Pending"
        case .paid: "Paid"
        case .cancelled: "Cancelled"
        case .overdue: "Overdue"
        }
    }
}

struct InvoiceClientSummary: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let company: String?
}

struct InvoiceContractSummary: Codable, Identifiable, Equatable {
    let id: String
    let name: String
}

struct InvoicePaymentSummary: Codable, Identifiable, Equatable {
    let id: String
    let amount: String
    let currency: String
    let paidAt: Date
    let method: String?
    let note: String?
    let active: Bool
    let deletedAt: Date?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        amount = try container.decode(String.self, forKey: .amount)
        currency = try container.decode(String.self, forKey: .currency)
        method = try container.decodeIfPresent(String.self, forKey: .method)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        active = try container.decodeIfPresent(Bool.self, forKey: .active) ?? true
        paidAt = try BusinessDate.decode(container.decode(String.self, forKey: .paidAt))
        if let deletedAtValue = try container.decodeIfPresent(String.self, forKey: .deletedAt) {
            deletedAt = try TimestampDate.decode(deletedAtValue)
        } else {
            deletedAt = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case amount
        case currency
        case paidAt
        case method
        case note
        case active
        case deletedAt
    }
}

struct InvoiceWorkLogSummary: Codable, Identifiable, Equatable {
    let id: String
    let contractId: String
    let workDate: Date
    let hours: String
    let isOvertime: Bool
    let note: String?
    let active: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        contractId = try container.decode(String.self, forKey: .contractId)
        hours = try container.decode(String.self, forKey: .hours)
        isOvertime = try container.decode(Bool.self, forKey: .isOvertime)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        active = try container.decodeIfPresent(Bool.self, forKey: .active) ?? true
        workDate = try BusinessDate.decode(container.decode(String.self, forKey: .workDate))
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case contractId
        case workDate
        case hours
        case isOvertime
        case note
        case active
    }
}

struct Invoice: Codable, Identifiable, Equatable {
    let id: String
    let clientId: String
    let contractId: String?
    let periodFrom: Date
    let periodTo: Date
    let currency: String
    let subtotal: String
    let paidAmount: String
    let outstandingAmount: String
    let status: InvoiceStatus
    let effectiveStatus: InvoiceStatus
    let issuedAt: Date
    let dueDate: Date?
    let note: String?
    let active: Bool
    let deletedAt: Date?
    let client: InvoiceClientSummary
    let contract: InvoiceContractSummary?
    let workLogs: [InvoiceWorkLogSummary]
    let payments: [InvoicePaymentSummary]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        clientId = try container.decode(String.self, forKey: .clientId)
        contractId = try container.decodeIfPresent(String.self, forKey: .contractId)
        currency = try container.decode(String.self, forKey: .currency)
        subtotal = try container.decode(String.self, forKey: .subtotal)
        paidAmount = try container.decode(String.self, forKey: .paidAmount)
        outstandingAmount = try container.decode(String.self, forKey: .outstandingAmount)
        status = try container.decode(InvoiceStatus.self, forKey: .status)
        effectiveStatus = try container.decode(InvoiceStatus.self, forKey: .effectiveStatus)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        active = try container.decode(Bool.self, forKey: .active)
        client = try container.decode(InvoiceClientSummary.self, forKey: .client)
        contract = try container.decodeIfPresent(InvoiceContractSummary.self, forKey: .contract)
        workLogs = try container.decodeIfPresent([InvoiceWorkLogSummary].self, forKey: .workLogs) ?? []
        payments = try container.decodeIfPresent([InvoicePaymentSummary].self, forKey: .payments) ?? []

        periodFrom = try BusinessDate.decode(container.decode(String.self, forKey: .periodFrom))
        periodTo = try BusinessDate.decode(container.decode(String.self, forKey: .periodTo))
        issuedAt = try BusinessDate.decode(container.decode(String.self, forKey: .issuedAt))
        if let dueDateValue = try container.decodeIfPresent(String.self, forKey: .dueDate) {
            dueDate = try BusinessDate.decode(dueDateValue)
        } else {
            dueDate = nil
        }
        if let deletedAtValue = try container.decodeIfPresent(String.self, forKey: .deletedAt) {
            deletedAt = try TimestampDate.decode(deletedAtValue)
        } else {
            deletedAt = nil
        }
    }

    static func encodeDateOnly(_ date: Date) -> String {
        BusinessDate.encode(date)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case clientId
        case contractId
        case periodFrom
        case periodTo
        case currency
        case subtotal
        case paidAmount
        case outstandingAmount
        case status
        case effectiveStatus
        case issuedAt
        case dueDate
        case note
        case active
        case deletedAt
        case client
        case contract
        case workLogs
        case payments
    }
}
