import Foundation

struct PaymentInvoiceSummary: Codable, Identifiable, Equatable {
    let id: String
    let number: String?
    let subtotal: String
    let currency: String
    let status: InvoiceStatus
    let paidAmount: String?
    let outstandingAmount: String?
    let effectiveStatus: InvoiceStatus?
}

struct PaymentClientSummary: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let company: String?
}

struct Payment: Codable, Identifiable, Equatable {
    let id: String
    let invoiceId: String
    let clientId: String
    let amount: String
    let currency: String
    let paidAt: Date
    let method: String?
    let note: String?
    let active: Bool
    let deletedAt: Date?
    let invoice: PaymentInvoiceSummary
    let client: PaymentClientSummary

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        invoiceId = try container.decode(String.self, forKey: .invoiceId)
        clientId = try container.decode(String.self, forKey: .clientId)
        amount = try container.decode(String.self, forKey: .amount)
        currency = try container.decode(String.self, forKey: .currency)
        method = try container.decodeIfPresent(String.self, forKey: .method)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        active = try container.decode(Bool.self, forKey: .active)
        invoice = try container.decode(PaymentInvoiceSummary.self, forKey: .invoice)
        client = try container.decode(PaymentClientSummary.self, forKey: .client)
        paidAt = try BusinessDate.decode(container.decode(String.self, forKey: .paidAt))
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
        case invoiceId
        case clientId
        case amount
        case currency
        case paidAt
        case method
        case note
        case active
        case deletedAt
        case invoice
        case client
    }
}
