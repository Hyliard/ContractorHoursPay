import Foundation
import Combine

@MainActor
final class PaymentsViewModel: ObservableObject {
    @Published var payments: [Payment] = []
    @Published var includeInactive = false
    @Published var hasFromDate = false
    @Published var fromDate = Date()
    @Published var hasToDate = false
    @Published var toDate = Date()
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: PaymentAPIService
    private let invoiceId: String?
    private let clientId: String?

    init(invoiceId: String? = nil, clientId: String? = nil, includeInactive: Bool = false) {
        self.invoiceId = invoiceId
        self.clientId = clientId
        self.includeInactive = includeInactive
        self.service = PaymentAPIService()
    }

    init(invoiceId: String? = nil, clientId: String? = nil, includeInactive: Bool = false, service: PaymentAPIService) {
        self.invoiceId = invoiceId
        self.clientId = clientId
        self.includeInactive = includeInactive
        self.service = service
    }

    var activePayments: [Payment] {
        payments.filter(\.active)
    }

    var archivedPayments: [Payment] {
        payments.filter { !$0.active }
    }

    func load(using authManager: AuthManager) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            payments = try await service.fetchPayments(
                includeInactive: includeInactive,
                invoiceId: invoiceId,
                clientId: clientId,
                from: hasFromDate ? Payment.encodeDateOnly(fromDate) : nil,
                to: hasToDate ? Payment.encodeDateOnly(toDate) : nil,
                token: requiredToken(from: authManager)
            )
        } catch {
            errorMessage = userFacingPaymentError(error)
        }
    }

    func fetchPayment(id: String, using authManager: AuthManager) async throws -> Payment {
        try await service.fetchPayment(id: id, token: requiredToken(from: authManager))
    }

    func create(
        invoiceId: String,
        amount: String,
        currency: String,
        paidAt: Date,
        method: String?,
        note: String?,
        using authManager: AuthManager
    ) async throws -> Payment {
        let payment = try await service.createPayment(
            invoiceId: invoiceId,
            amount: amount,
            currency: currency,
            paidAt: Payment.encodeDateOnly(paidAt),
            method: method,
            note: note,
            token: requiredToken(from: authManager)
        )
        upsert(payment)
        return payment
    }

    func update(
        id: String,
        amount: String,
        currency: String,
        paidAt: Date,
        method: String?,
        note: String?,
        active: Bool,
        using authManager: AuthManager
    ) async throws -> Payment {
        let payment = try await service.updatePayment(
            id: id,
            amount: amount,
            currency: currency,
            paidAt: Payment.encodeDateOnly(paidAt),
            method: method,
            note: note,
            active: active,
            token: requiredToken(from: authManager)
        )
        upsert(payment)
        return payment
    }

    func archive(_ payment: Payment, using authManager: AuthManager) async throws -> Payment {
        let archived = try await service.archivePayment(id: payment.id, token: requiredToken(from: authManager))
        if includeInactive {
            upsert(archived)
        } else {
            payments.removeAll { $0.id == payment.id }
        }
        return archived
    }

    func reactivate(_ payment: Payment, using authManager: AuthManager) async throws -> Payment {
        try await update(
            id: payment.id,
            amount: payment.amount,
            currency: payment.currency,
            paidAt: payment.paidAt,
            method: payment.method,
            note: payment.note,
            active: true,
            using: authManager
        )
    }

    private func upsert(_ payment: Payment) {
        if let index = payments.firstIndex(where: { $0.id == payment.id }) {
            payments[index] = payment
        } else if includeInactive || payment.active {
            payments.insert(payment, at: 0)
        }
    }

    private func requiredToken(from authManager: AuthManager) throws -> String {
        guard let token = authManager.token else {
            throw APIError.notAuthenticated
        }
        return token
    }
}

func userFacingPaymentError(_ error: Error) -> String {
    if case APIError.server(_, let statusCode) = error {
        switch statusCode {
        case 409:
            return "El pago supera el saldo pendiente o la moneda no coincide con la factura."
        case 404:
            return "El pago no está disponible."
        case 400:
            return "Revisá los datos del pago."
        default:
            break
        }
    }
    return error.localizedDescription
}
