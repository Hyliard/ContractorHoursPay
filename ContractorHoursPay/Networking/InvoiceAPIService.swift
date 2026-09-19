import Foundation

struct InvoiceAPIService {
    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func fetchInvoices(
        includeInactive: Bool = false,
        clientId: String? = nil,
        contractId: String? = nil,
        status: String? = nil,
        from: String? = nil,
        to: String? = nil,
        overdue: Bool? = nil,
        token: String
    ) async throws -> [Invoice] {
        var queryItems: [String] = []
        if includeInactive { queryItems.append("includeInactive=true") }
        if let clientId { queryItems.append("clientId=\(clientId)") }
        if let contractId { queryItems.append("contractId=\(contractId)") }
        if let status { queryItems.append("status=\(status)") }
        if let from { queryItems.append("from=\(from)") }
        if let to { queryItems.append("to=\(to)") }
        if let overdue { queryItems.append("overdue=\(overdue)") }

        let path = queryItems.isEmpty ? "api/invoices" : "api/invoices?\(queryItems.joined(separator: "&"))"
        let response: InvoiceListResponse = try await client.send(method: .get, path: path, token: token)
        return response.invoices
    }

    func fetchInvoice(id: String, token: String) async throws -> Invoice {
        let response: InvoiceResponse = try await client.send(method: .get, path: "api/invoices/\(id)", token: token)
        return response.invoice
    }

    func createInvoice(
        clientId: String,
        contractId: String?,
        periodFrom: String,
        periodTo: String,
        currency: String,
        subtotal: String,
        issuedAt: String,
        dueDate: String?,
        note: String?,
        workLogIds: [String],
        token: String
    ) async throws -> Invoice {
        let body = InvoiceCreateRequest(
            clientId: clientId,
            contractId: contractId,
            periodFrom: periodFrom,
            periodTo: periodTo,
            currency: currency,
            subtotal: subtotal,
            issuedAt: issuedAt,
            dueDate: dueDate,
            note: note,
            workLogIds: workLogIds
        )
        let response: InvoiceResponse = try await client.send(method: .post, path: "api/invoices", body: body, token: token)
        return response.invoice
    }

    func updateInvoice(
        id: String,
        periodFrom: String,
        periodTo: String,
        subtotal: String,
        issuedAt: String,
        dueDate: String?,
        note: String?,
        status: InvoiceStatus,
        active: Bool,
        token: String
    ) async throws -> Invoice {
        let body = InvoiceUpdateRequest(
            periodFrom: periodFrom,
            periodTo: periodTo,
            subtotal: subtotal,
            issuedAt: issuedAt,
            dueDate: dueDate,
            note: note,
            status: status.rawValue,
            active: active
        )
        let response: InvoiceResponse = try await client.send(method: .patch, path: "api/invoices/\(id)", body: body, token: token)
        return response.invoice
    }

    func archiveInvoice(id: String, token: String) async throws -> Invoice {
        let response: InvoiceResponse = try await client.send(method: .delete, path: "api/invoices/\(id)", token: token)
        return response.invoice
    }
}

private struct InvoiceCreateRequest: Encodable {
    let clientId: String
    let contractId: String?
    let periodFrom: String
    let periodTo: String
    let currency: String
    let subtotal: String
    let issuedAt: String
    let dueDate: String?
    let note: String?
    let workLogIds: [String]
}

private struct InvoiceUpdateRequest: Encodable {
    let periodFrom: String
    let periodTo: String
    let subtotal: String
    let issuedAt: String
    let dueDate: String?
    let note: String?
    let status: String
    let active: Bool
}

private struct InvoiceListResponse: Decodable {
    let invoices: [Invoice]

    init(from decoder: Decoder) throws {
        if let invoices = try? [Invoice](from: decoder) {
            self.invoices = invoices
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        invoices = try container.decode([Invoice].self, forKey: .invoices)
    }

    private enum CodingKeys: String, CodingKey {
        case invoices
    }
}

private struct InvoiceResponse: Decodable {
    let invoice: Invoice

    init(from decoder: Decoder) throws {
        if let invoice = try? Invoice(from: decoder) {
            self.invoice = invoice
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        invoice = try container.decode(Invoice.self, forKey: .invoice)
    }

    private enum CodingKeys: String, CodingKey {
        case invoice
    }
}
