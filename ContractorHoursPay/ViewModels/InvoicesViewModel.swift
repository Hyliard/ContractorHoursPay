import Foundation
import Combine

@MainActor
final class InvoicesViewModel: ObservableObject {
    @Published var invoices: [Invoice] = []
    @Published var includeInactive = false
    @Published var statusFilter: InvoiceStatus?
    @Published var hasFromDate = false
    @Published var fromDate = Date()
    @Published var hasToDate = false
    @Published var toDate = Date()
    @Published var showOverdueOnly = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: InvoiceAPIService
    private let clientId: String?
    private let contractId: String?

    init(clientId: String? = nil, contractId: String? = nil, includeInactive: Bool = false) {
        self.clientId = clientId
        self.contractId = contractId
        self.includeInactive = includeInactive
        self.service = InvoiceAPIService()
    }

    init(clientId: String? = nil, contractId: String? = nil, includeInactive: Bool = false, service: InvoiceAPIService) {
        self.clientId = clientId
        self.contractId = contractId
        self.includeInactive = includeInactive
        self.service = service
    }

    var activeInvoices: [Invoice] {
        invoices.filter(\.active)
    }

    var archivedInvoices: [Invoice] {
        invoices.filter { !$0.active }
    }

    func load(using authManager: AuthManager) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            invoices = try await service.fetchInvoices(
                includeInactive: includeInactive,
                clientId: clientId,
                contractId: contractId,
                status: statusFilter?.rawValue,
                from: hasFromDate ? Invoice.encodeDateOnly(fromDate) : nil,
                to: hasToDate ? Invoice.encodeDateOnly(toDate) : nil,
                overdue: showOverdueOnly ? true : nil,
                token: requiredToken(from: authManager)
            )
        } catch {
            errorMessage = userFacingInvoiceError(error)
        }
    }

    func fetchInvoice(id: String, using authManager: AuthManager) async throws -> Invoice {
        try await service.fetchInvoice(id: id, token: requiredToken(from: authManager))
    }

    func create(
        clientId: String,
        contractId: String?,
        periodFrom: Date,
        periodTo: Date,
        currency: String,
        subtotal: String,
        issuedAt: Date,
        dueDate: Date?,
        note: String?,
        workLogIds: [String],
        using authManager: AuthManager
    ) async throws -> Invoice {
        let invoice = try await service.createInvoice(
            clientId: clientId,
            contractId: contractId,
            periodFrom: Invoice.encodeDateOnly(periodFrom),
            periodTo: Invoice.encodeDateOnly(periodTo),
            currency: currency,
            subtotal: subtotal,
            issuedAt: Invoice.encodeDateOnly(issuedAt),
            dueDate: dueDate.map(Invoice.encodeDateOnly),
            note: note,
            workLogIds: workLogIds,
            token: requiredToken(from: authManager)
        )
        upsert(invoice)
        return invoice
    }

    func update(
        id: String,
        periodFrom: Date,
        periodTo: Date,
        subtotal: String,
        issuedAt: Date,
        dueDate: Date?,
        note: String?,
        status: InvoiceStatus,
        active: Bool,
        using authManager: AuthManager
    ) async throws -> Invoice {
        let invoice = try await service.updateInvoice(
            id: id,
            periodFrom: Invoice.encodeDateOnly(periodFrom),
            periodTo: Invoice.encodeDateOnly(periodTo),
            subtotal: subtotal,
            issuedAt: Invoice.encodeDateOnly(issuedAt),
            dueDate: dueDate.map(Invoice.encodeDateOnly),
            note: note,
            status: status,
            active: active,
            token: requiredToken(from: authManager)
        )
        upsert(invoice)
        return invoice
    }

    func archive(_ invoice: Invoice, using authManager: AuthManager) async throws -> Invoice {
        let archived = try await service.archiveInvoice(id: invoice.id, token: requiredToken(from: authManager))
        if includeInactive {
            upsert(archived)
        } else {
            invoices.removeAll { $0.id == invoice.id }
        }
        return archived
    }

    func reactivate(_ invoice: Invoice, using authManager: AuthManager) async throws -> Invoice {
        try await update(
            id: invoice.id,
            periodFrom: invoice.periodFrom,
            periodTo: invoice.periodTo,
            subtotal: invoice.subtotal,
            issuedAt: invoice.issuedAt,
            dueDate: invoice.dueDate,
            note: invoice.note,
            status: invoice.status,
            active: true,
            using: authManager
        )
    }

    private func upsert(_ invoice: Invoice) {
        if let index = invoices.firstIndex(where: { $0.id == invoice.id }) {
            invoices[index] = invoice
        } else if includeInactive || invoice.active {
            invoices.insert(invoice, at: 0)
        }
    }

    private func requiredToken(from authManager: AuthManager) throws -> String {
        guard let token = authManager.token else {
            throw APIError.notAuthenticated
        }
        return token
    }
}

func userFacingInvoiceError(_ error: Error) -> String {
    if case APIError.server(_, let statusCode) = error {
        switch statusCode {
        case 409:
            return "Uno o más registros ya fueron facturados o el recurso seleccionado está archivado."
        case 404:
            return "La factura no está disponible."
        case 400:
            return "Revisá los datos de la factura."
        default:
            break
        }
    }
    return error.localizedDescription
}
