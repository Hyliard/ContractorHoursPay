import Foundation

struct CurrencyAmountSummary: Identifiable, Equatable {
    let currency: String
    let amount: Decimal

    var id: String { currency }
}

enum BusinessDate {
    static func encode(_ date: Date) -> String {
        makeFormatter().string(from: date)
    }

    static func decode(_ value: String) throws -> Date {
        if let date = makeFormatter().date(from: value) {
            return Calendar.current.startOfDay(for: date)
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Invalid date: \(value)")
        )
    }

    private static func makeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

enum TimestampDate {
    static func decode(_ value: String) throws -> Date {
        if let date = fractionalFormatter.date(from: value) ?? formatter.date(from: value) {
            return date
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Invalid timestamp: \(value)")
        )
    }

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

func decimalValue(_ value: String) -> Decimal? {
    Decimal(string: normalizedRate(value))
}

func isValidCurrencyCode(_ value: String) -> Bool {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
        .range(of: #"^[A-Za-z]{3}$"#, options: .regularExpression) != nil
}

func formattedCurrencyGroups(_ summaries: [CurrencyAmountSummary], hideAmounts: Bool = false) -> String {
    if summaries.isEmpty {
        return "N/A"
    }

    return summaries
        .sorted { $0.currency < $1.currency }
        .map { AppPreferences.financialAmount($0.amount, currency: $0.currency, hideAmounts: hideAmounts) }
        .joined(separator: "\n")
}

extension Date {
    var startOfBusinessDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}

extension Decimal {
    var formattedHours: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "0"
    }

    func formattedCurrency(code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "\(code) 0"
    }
}
