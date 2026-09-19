import Foundation

struct PaymentAPIService {
    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func fetchPayments(
        includeInactive: Bool = false,
        invoiceId: String? = nil,
        clientId: String? = nil,
        from: String? = nil,
        to: String? = nil,
        token: String
    ) async throws -> [Payment] {
        var queryItems: [String] = []
        if includeInactive { queryItems.append("includeInactive=true") }
        if let invoiceId { queryItems.append("invoiceId=\(invoiceId)") }
        if let clientId { queryItems.append("clientId=\(clientId)") }
        if let from { queryItems.append("from=\(from)") }
        if let to { queryItems.append("to=\(to)") }

        let path = queryItems.isEmpty ? "api/payments" : "api/payments?\(queryItems.joined(separator: "&"))"
        let response: PaymentListResponse = try await client.send(method: .get, path: path, token: token)
        return response.payments
    }

    func fetchPayment(id: String, token: String) async throws -> Payment {
        let response: PaymentResponse = try await client.send(method: .get, path: "api/payments/\(id)", token: token)
        return response.payment
    }

    func createPayment(
        invoiceId: String,
        amount: String,
        currency: String,
        paidAt: String,
        method: String?,
        note: String?,
        token: String
    ) async throws -> Payment {
        let body = PaymentCreateRequest(
            invoiceId: invoiceId,
            amount: amount,
            currency: currency,
            paidAt: paidAt,
            method: method,
            note: note
        )
        let response: PaymentResponse = try await client.send(method: .post, path: "api/payments", body: body, token: token)
        return response.payment
    }

    func updatePayment(
        id: String,
        amount: String,
        currency: String,
        paidAt: String,
        method: String?,
        note: String?,
        active: Bool,
        token: String
    ) async throws -> Payment {
        let body = PaymentUpdateRequest(
            amount: amount,
            currency: currency,
            paidAt: paidAt,
            method: method,
            note: note,
            active: active
        )
        let response: PaymentResponse = try await client.send(method: .patch, path: "api/payments/\(id)", body: body, token: token)
        return response.payment
    }

    func archivePayment(id: String, token: String) async throws -> Payment {
        let response: PaymentResponse = try await client.send(method: .delete, path: "api/payments/\(id)", token: token)
        return response.payment
    }
}

private struct PaymentCreateRequest: Encodable {
    let invoiceId: String
    let amount: String
    let currency: String
    let paidAt: String
    let method: String?
    let note: String?
}

private struct PaymentUpdateRequest: Encodable {
    let amount: String
    let currency: String
    let paidAt: String
    let method: String?
    let note: String?
    let active: Bool
}

private struct PaymentListResponse: Decodable {
    let payments: [Payment]

    init(from decoder: Decoder) throws {
        if let payments = try? [Payment](from: decoder) {
            self.payments = payments
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        payments = try container.decode([Payment].self, forKey: .payments)
    }

    private enum CodingKeys: String, CodingKey {
        case payments
    }
}

private struct PaymentResponse: Decodable {
    let payment: Payment

    init(from decoder: Decoder) throws {
        if let payment = try? Payment(from: decoder) {
            self.payment = payment
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        payment = try container.decode(Payment.self, forKey: .payment)
    }

    private enum CodingKeys: String, CodingKey {
        case payment
    }
}
