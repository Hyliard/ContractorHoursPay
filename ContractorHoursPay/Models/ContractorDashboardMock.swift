import Foundation

struct ContractorClient: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
}

struct ContractorSummary: Equatable {
    let currency: String
    let hourlyRate: Decimal
    let hoursWorked: Decimal
    let paidAmount: Decimal
    let pendingAmount: Decimal

    var estimatedIncome: Decimal {
        hoursWorked * hourlyRate
    }
}

struct UpcomingPayment: Identifiable, Equatable {
    let id: String
    let client: ContractorClient
    let amount: Decimal
    let currency: String
    let date: Date
    let status: String
}

struct DashboardWorkLog: Identifiable, Equatable {
    let id: String
    let client: ContractorClient
    let date: Date
    let hours: Decimal
    let hourlyRate: Decimal
    let currency: String
    let note: String?

    var amount: Decimal {
        hours * hourlyRate
    }
}

enum ContractorDashboardMock {
    static let clients = [
        ContractorClient(id: "mphasis", name: "Mphasis"),
        ContractorClient(id: "client-x", name: "Cliente X")
    ]

    static let summary = ContractorSummary(
        currency: "USD",
        hourlyRate: 30,
        hoursWorked: 144,
        paidAmount: 3600,
        pendingAmount: 720
    )

    static let upcomingPayment = UpcomingPayment(
        id: "next-payment",
        client: clients[0],
        amount: 2400,
        currency: "USD",
        date: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 15)) ?? .now,
        status: "Esperado"
    )

    static let recentWorkLogs = [
        DashboardWorkLog(
            id: "today",
            client: clients[0],
            date: .now,
            hours: 8,
            hourlyRate: 30,
            currency: "USD",
            note: nil
        ),
        DashboardWorkLog(
            id: "yesterday",
            client: clients[0],
            date: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
            hours: 8,
            hourlyRate: 30,
            currency: "USD",
            note: nil
        ),
        DashboardWorkLog(
            id: "overtime",
            client: clients[1],
            date: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 3)) ?? .now,
            hours: 4,
            hourlyRate: 45,
            currency: "USD",
            note: "OT"
        )
    ]
}
