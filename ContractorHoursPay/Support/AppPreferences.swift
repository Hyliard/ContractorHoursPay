import SwiftUI

enum AppPreferenceKey {
    static let themePreference = "profile.themePreference"
    static let hideAmounts = "profile.hideAmounts"
    static let highlightOvertime = "profile.highlightOvertime"
    static let confirmBeforeArchive = "profile.confirmBeforeArchive"
    static let weekStartsOn = "profile.weekStartsOn"
    static let hourFormat = "profile.hourFormat"
    static let preferredCurrency = "profile.preferredCurrency"
}

enum AppThemePreference: String {
    case system
    case light
    case dark

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

enum AppPreferences {
    static func colorScheme(for rawValue: String) -> ColorScheme? {
        (AppThemePreference(rawValue: rawValue) ?? .system).preferredColorScheme
    }

    static func financialAmount(_ amount: Decimal, currency: String, hideAmounts: Bool) -> String {
        if hideAmounts {
            return "\(currency) ••••••"
        }

        return amount.formattedCurrency(code: currency)
    }

    static func financialAmount(_ value: String, currency: String, hideAmounts: Bool) -> String {
        financialAmount(decimalValue(value) ?? 0, currency: currency, hideAmounts: hideAmounts)
    }

    static func startOfWeek(for date: Date, weekStartsOn rawValue: String) -> Date {
        let firstWeekday = rawValue == "sunday" ? 1 : 2
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = firstWeekday

        let weekday = calendar.component(.weekday, from: date)
        let daysFromStart = (weekday - firstWeekday + 7) % 7
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -daysFromStart, to: startOfDay) ?? startOfDay
    }

    static func formattedHours(_ value: String, hourFormat: String) -> String {
        formattedHours(decimalValue(value) ?? 0, hourFormat: hourFormat)
    }

    static func formattedHours(_ value: Decimal, hourFormat: String) -> String {
        if hourFormat == "compact" {
            return compactHours(value)
        }

        return "\(value.formattedHours) h"
    }

    static func currencySortPriority(_ currency: String, preferredCurrency: String) -> String {
        currency.uppercased() == preferredCurrency.uppercased() ? "0-\(currency)" : "1-\(currency)"
    }

    private static func compactHours(_ value: Decimal) -> String {
        let minutesDecimal = value * 60
        let roundedMinutes = NSDecimalNumber(decimal: minutesDecimal).rounding(
            accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: .plain,
                scale: 0,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            )
        )
        let totalMinutes = max(0, roundedMinutes.intValue)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours) h \(minutes) min"
        }

        if hours > 0 {
            return "\(hours) h"
        }

        return "\(minutes) min"
    }
}
