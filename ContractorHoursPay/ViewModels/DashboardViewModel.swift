import Foundation
import Combine

struct DashboardCurrencySummary: Identifiable, Equatable {
    let currency: String
    let estimatedIncome: Decimal
    let hours: Decimal

    var id: String { currency }
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var monthlyWorkLogs: [WorkLog] = []
    @Published var recentWorkLogs: [WorkLog] = []
    @Published var summariesByCurrency: [DashboardCurrencySummary] = []
    @Published var totalHours: Decimal = 0
    @Published var overtimeHours: Decimal = 0
    @Published var workLogCount = 0
    @Published var workedContractCount = 0
    @Published var pendingSummaries: [CurrencyAmountSummary] = []
    @Published var paidSummaries: [CurrencyAmountSummary] = []
    @Published var overdueSummaries: [CurrencyAmountSummary] = []
    @Published var nextDueInvoice: Invoice?

    private let workLogService: WorkLogAPIService
    private let invoiceService: InvoiceAPIService
    private let paymentService: PaymentAPIService
    private var authManager: AuthManager?
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.workLogService = WorkLogAPIService()
        self.invoiceService = InvoiceAPIService()
        self.paymentService = PaymentAPIService()
        self.calendar = calendar
    }

    init(
        workLogService: WorkLogAPIService,
        invoiceService: InvoiceAPIService = InvoiceAPIService(),
        paymentService: PaymentAPIService = PaymentAPIService(),
        calendar: Calendar = .current
    ) {
        self.workLogService = workLogService
        self.invoiceService = invoiceService
        self.paymentService = paymentService
        self.calendar = calendar
    }

    var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date())
    }

    func configure(authManager: AuthManager) {
        self.authManager = authManager
    }

    func loadDashboard() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            guard let token = authManager?.token else {
                throw APIError.notAuthenticated
            }

            let range = monthRange(for: Date())
            async let monthly = workLogService.fetchWorkLogs(
                includeInactive: false,
                from: WorkLog.encodeDateOnly(range.start),
                to: WorkLog.encodeDateOnly(range.end),
                token: token
            )
            async let recent = workLogService.fetchWorkLogs(includeInactive: false, token: token)
            async let invoices = invoiceService.fetchInvoices(includeInactive: false, token: token)
            async let payments = paymentService.fetchPayments(includeInactive: false, token: token)

            let fetchedMonthlyLogs = try await monthly
            let fetchedRecentLogs = try await recent
            let fetchedInvoices = try await invoices
            let fetchedPayments = try await payments
            let monthlyLogs = fetchedMonthlyLogs.filter(\.active)
            let recentLogs = fetchedRecentLogs.filter(\.active)

            monthlyWorkLogs = monthlyLogs.sorted { $0.workDate > $1.workDate }
            recentWorkLogs = Array(recentLogs.sorted { $0.workDate > $1.workDate }.prefix(4))
            rebuildSummaries(from: monthlyLogs)
            rebuildFinancialSummaries(invoices: fetchedInvoices, payments: fetchedPayments)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rebuildSummaries(from workLogs: [WorkLog]) {
        totalHours = 0
        overtimeHours = 0
        workLogCount = workLogs.count
        workedContractCount = Set(workLogs.map(\.contractId)).count

        var incomeByCurrency: [String: Decimal] = [:]
        var hoursByCurrency: [String: Decimal] = [:]

        for workLog in workLogs {
            guard let hours = Decimal(string: normalizedRate(workLog.hours)),
                  let hourlyRate = Decimal(string: normalizedRate(workLog.contract.hourlyRate)) else {
                continue
            }

            let currency = workLog.contract.currency
            let rate = hourlyRate
            let income = hours * rate

            totalHours += hours
            if workLog.isOvertime {
                overtimeHours += hours
            }
            incomeByCurrency[currency, default: 0] += income
            hoursByCurrency[currency, default: 0] += hours
        }

        summariesByCurrency = incomeByCurrency
            .map { currency, income in
                DashboardCurrencySummary(
                    currency: currency,
                    estimatedIncome: income,
                    hours: hoursByCurrency[currency, default: 0]
                )
            }
            .sorted { $0.currency < $1.currency }
    }

    private func rebuildFinancialSummaries(invoices: [Invoice], payments: [Payment]) {
        let activeInvoices = invoices.filter { $0.active && $0.effectiveStatus != .cancelled }
        let activePayments = payments.filter(\.active)

        pendingSummaries = summarizeAmounts(
            activeInvoices.compactMap { invoice in
                guard let amount = decimalValue(invoice.outstandingAmount), amount > 0 else {
                    return nil
                }
                return (invoice.currency, amount)
            }
        )

        paidSummaries = summarizeAmounts(
            activePayments.compactMap { payment in
                guard let amount = decimalValue(payment.amount), amount > 0 else {
                    return nil
                }
                return (payment.currency, amount)
            }
        )

        overdueSummaries = summarizeAmounts(
            activeInvoices.compactMap { invoice in
                guard invoice.effectiveStatus == .overdue,
                      let amount = decimalValue(invoice.outstandingAmount),
                      amount > 0 else {
                    return nil
                }
                return (invoice.currency, amount)
            }
        )

        let today = Date().startOfBusinessDay
        nextDueInvoice = activeInvoices
            .filter { invoice in
                guard let dueDate = invoice.dueDate,
                      let amount = decimalValue(invoice.outstandingAmount) else {
                    return false
                }
                return dueDate.startOfBusinessDay >= today && amount > 0
            }
            .sorted { $0.dueDate ?? .distantFuture < $1.dueDate ?? .distantFuture }
            .first
    }

    private func summarizeAmounts(_ amounts: [(currency: String, amount: Decimal)]) -> [CurrencyAmountSummary] {
        var totals: [String: Decimal] = [:]
        for amount in amounts {
            totals[amount.currency, default: 0] += amount.amount
        }
        return totals
            .map { CurrencyAmountSummary(currency: $0.key, amount: $0.value) }
            .sorted { $0.currency < $1.currency }
    }

    private func monthRange(for date: Date) -> (start: Date, end: Date) {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let end = calendar.date(byAdding: DateComponents(day: -1), to: interval.end) else {
            return (date, date)
        }
        return (interval.start, end)
    }
}
