import Foundation

enum DeveloperLogSanitizer {
    static let previewLimit = 2_000

    private static let sensitiveKeys = [
        "authorization",
        "password",
        "token",
        "accesstoken",
        "refreshtoken",
        "secret",
        "jwt",
        "cookie"
    ]

    static func sanitizedPreview(from data: Data?, contentType: String? = nil) -> String? {
        guard let data, !data.isEmpty else { return nil }

        if let contentType, isBinary(contentType) {
            return "<binary data: \(data.count) bytes>"
        }

        guard let text = String(data: data, encoding: .utf8) else {
            return "<non-text data: \(data.count) bytes>"
        }

        return sanitizedText(text)
    }

    static func sanitizedText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        if let data = trimmed.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data),
           JSONSerialization.isValidJSONObject(object),
           let sanitizedData = try? JSONSerialization.data(
                withJSONObject: sanitizeJSONObject(object),
                options: [.prettyPrinted, .sortedKeys]
           ),
           let sanitizedJSON = String(data: sanitizedData, encoding: .utf8) {
            return truncated(sanitizedJSON)
        }

        return truncated(redactKnownPatterns(trimmed))
    }

    static func truncated(_ text: String, limit: Int = previewLimit) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "\n… <truncated>"
    }

    private static func sanitizeJSONObject(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, pair in
                if isSensitiveKey(pair.key) {
                    result[pair.key] = "<redacted>"
                } else {
                    result[pair.key] = sanitizeJSONObject(pair.value)
                }
            }
        }

        if let array = value as? [Any] {
            return array.map(sanitizeJSONObject)
        }

        return value
    }

    private static func isSensitiveKey(_ key: String) -> Bool {
        let normalized = key.lowercased().replacingOccurrences(of: "_", with: "")
        return sensitiveKeys.contains { normalized.contains($0) }
    }

    private static func isBinary(_ contentType: String) -> Bool {
        let lowercased = contentType.lowercased()
        return lowercased.contains("multipart/form-data")
            || lowercased.contains("image/")
            || lowercased.contains("octet-stream")
    }

    private static func redactKnownPatterns(_ text: String) -> String {
        var result = text
        let patterns = [
            #"Bearer\s+[A-Za-z0-9_\-\.]+"#,
            #""authorization"\s*:\s*"[^"]+""#,
            #""password"\s*:\s*"[^"]+""#,
            #""token"\s*:\s*"[^"]+""#
        ]

        for pattern in patterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "<redacted>",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return result
    }
}
