import SwiftUI

enum AppPreferenceKey {
    static let themePreference = "profile.themePreference"
    static let hideAmounts = "profile.hideAmounts"
    static let highlightOvertime = "profile.highlightOvertime"
    static let confirmBeforeArchive = "profile.confirmBeforeArchive"
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
}
