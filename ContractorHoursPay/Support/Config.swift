import Foundation

enum AppConfig {
    static var environmentName: String {
        configuredValue(for: "APIEnvironment", environmentKey: "API_ENVIRONMENT") ?? "Unknown"
    }

    static var baseURL: URL {
        let value = configuredValue(for: "APIBaseURL", environmentKey: "API_BASE_URL") ?? ""
        guard let url = URL(string: value), url.scheme != nil, url.host != nil else {
            preconditionFailure("APIBaseURL is missing or invalid. Received: \(value.isEmpty ? "<empty>" : value)")
        }
        return url
    }

    static func logDebugConfiguration() {
        #if DEBUG
        let environment = configuredValue(for: "APIEnvironment", environmentKey: "API_ENVIRONMENT")
        let baseURLValue = configuredValue(for: "APIBaseURL", environmentKey: "API_BASE_URL")
        print("[API] Environment: \(environment ?? "Missing")")
        print("[API] Base URL: \(baseURLValue ?? "Missing")")
        #endif
    }

    private static func configuredValue(for infoKey: String, environmentKey: String) -> String? {
        if let value = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String,
           isResolved(value) {
            return value
        }

        #if DEBUG
        if let value = ProcessInfo.processInfo.environment[environmentKey],
           isResolved(value) {
            return value
        }

        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            switch infoKey {
            case "APIBaseURL":
                return "http://localhost:3000"
            case "APIEnvironment":
                return "Preview"
            default:
                return nil
            }
        }
        #endif

        return nil
    }

    private static func isResolved(_ value: String) -> Bool {
        !value.isEmpty && !value.hasPrefix("$(")
    }
}
