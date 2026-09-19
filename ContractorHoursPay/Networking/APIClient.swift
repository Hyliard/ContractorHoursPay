import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Body vacío para requests que no necesitan enviar nada (ej: GET, DELETE
/// sin payload). Evita tener que duplicar cada función con/sin body.
struct EmptyBody: Encodable {}

/// Cliente HTTP genérico sobre URLSession. No depende de ninguna librería
/// externa: usa async/await nativo de Swift.
struct APIClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Con body, con respuesta decodificada

    func send<Body: Encodable, Response: Decodable>(
        method: HTTPMethod,
        path: String,
        body: Body,
        token: String? = nil
    ) async throws -> Response {
        let data = try await sendRaw(method: method, path: path, body: body, token: token)
        return try decode(data, method: method.rawValue, path: path)
    }

    // MARK: - Sin body, con respuesta decodificada

    func send<Response: Decodable>(
        method: HTTPMethod,
        path: String,
        token: String? = nil
    ) async throws -> Response {
        let data = try await sendRaw(method: method, path: path, body: Optional<EmptyBody>.none, token: token)
        return try decode(data, method: method.rawValue, path: path)
    }

    // MARK: - Sin body, sin necesidad de leer la respuesta

    @discardableResult
    func sendNoContent(
        method: HTTPMethod,
        path: String,
        token: String? = nil
    ) async throws -> Data {
        try await sendRaw(method: method, path: path, body: Optional<EmptyBody>.none, token: token)
    }

    // MARK: - Con body, sin necesidad de leer la respuesta

    @discardableResult
    func sendNoContent<Body: Encodable>(
        method: HTTPMethod,
        path: String,
        body: Body,
        token: String? = nil
    ) async throws -> Data {
        try await sendRaw(method: method, path: path, body: body, token: token)
    }

    // MARK: - Bytes sin decodificar

    func sendData(
        method: HTTPMethod,
        path: String,
        token: String? = nil
    ) async throws -> Data {
        try await sendRaw(method: method, path: path, body: Optional<EmptyBody>.none, token: token)
    }

    // MARK: - Multipart

    func sendMultipart<Response: Decodable>(
        path: String,
        fieldName: String,
        fileName: String,
        mimeType: String,
        data: Data,
        token: String? = nil
    ) async throws -> Response {
        let boundary = "Boundary-\(UUID().uuidString)"
        guard var request = makeRequest(method: .post, path: path, token: token, contentType: "multipart/form-data; boundary=\(boundary)") else {
            throw APIError.invalidURL
        }
        request.httpBody = multipartBody(
            boundary: boundary,
            fieldName: fieldName,
            fileName: fileName,
            mimeType: mimeType,
            data: data
        )

        let responseData = try await send(
            request,
            requestPreview: "<multipart form data: \(fieldName), \(mimeType), \(data.count) bytes>"
        )
        return try decode(responseData, method: HTTPMethod.post.rawValue, path: path)
    }

    // MARK: - Privados

    private func decode<Response: Decodable>(_ data: Data, method: String, path: String) throws -> Response {
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            recordDecodingFailure(method: method, path: path, data: data, error: error)
            throw APIError.decoding
        }
    }

    private func recordDecodingFailure(method: String, path: String, data: Data, error: Error) {
        let responsePreview = DeveloperLogSanitizer.sanitizedPreview(from: data)
        let message = "Decoding failed: \(decodingErrorDescription(error))"
        let entry = NetworkDebugEntry(
            timestamp: Date(),
            method: method,
            endpoint: path,
            statusCode: nil,
            durationMs: 0,
            errorMessage: DeveloperLogSanitizer.sanitizedText(message),
            requestPreview: nil,
            responsePreview: responsePreview
        )

        Task { @MainActor in
            NetworkDebugStore.shared.add(entry)
            DeveloperLogger.shared.log(.error, "\(method) \(path) \(message)")
        }
    }

    private func decodingErrorDescription(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }

        switch decodingError {
        case .keyNotFound(let key, let context):
            return "keyNotFound '\(key.stringValue)' at \(codingPath(context.codingPath)); \(context.debugDescription)"
        case .typeMismatch(let type, let context):
            return "typeMismatch '\(type)' at \(codingPath(context.codingPath)); \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "valueNotFound '\(type)' at \(codingPath(context.codingPath)); \(context.debugDescription)"
        case .dataCorrupted(let context):
            return "dataCorrupted at \(codingPath(context.codingPath)); \(context.debugDescription)"
        @unknown default:
            return decodingError.localizedDescription
        }
    }

    private func codingPath(_ path: [CodingKey]) -> String {
        if path.isEmpty {
            return "<root>"
        }

        return path.map { key in
            if let intValue = key.intValue {
                return "[\(intValue)]"
            }
            return key.stringValue
        }
        .joined(separator: ".")
    }

    private func sendRaw<Body: Encodable>(
        method: HTTPMethod,
        path: String,
        body: Body?,
        token: String?
    ) async throws -> Data {
        guard var request = makeRequest(method: method, path: path, token: token) else {
            throw APIError.invalidURL
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        return try await send(request)
    }

    private func send(_ request: URLRequest, requestPreview explicitRequestPreview: String? = nil) async throws -> Data {
        let startedAt = Date()
        let method = request.httpMethod ?? "GET"
        let endpoint = endpointDescription(for: request)
        let requestPreview = explicitRequestPreview
            ?? DeveloperLogSanitizer.sanitizedPreview(
                from: request.httpBody,
                contentType: request.value(forHTTPHeaderField: "Content-Type")
            )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let apiError = APIError.network(error.localizedDescription)
            recordDebugEntry(
                method: method,
                endpoint: endpoint,
                statusCode: nil,
                startedAt: startedAt,
                requestPreview: requestPreview,
                responsePreview: nil,
                errorMessage: apiError.localizedDescription
            )
            throw apiError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            let apiError = APIError.invalidResponse
            recordDebugEntry(
                method: method,
                endpoint: endpoint,
                statusCode: nil,
                startedAt: startedAt,
                requestPreview: requestPreview,
                responsePreview: DeveloperLogSanitizer.sanitizedPreview(from: data),
                errorMessage: apiError.localizedDescription
            )
            throw apiError
        }

        let responsePreview = DeveloperLogSanitizer.sanitizedPreview(
            from: data,
            contentType: httpResponse.value(forHTTPHeaderField: "Content-Type")
        )

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiError: APIError
            if httpResponse.statusCode == 401 {
                apiError = .notAuthenticated
            } else if let errorPayload = try? JSONDecoder().decode(APIErrorPayload.self, from: data) {
                apiError = .server(message: errorPayload.error.message, statusCode: httpResponse.statusCode)
            } else {
                apiError = .server(message: "Ocurrió un error inesperado.", statusCode: httpResponse.statusCode)
            }

            recordDebugEntry(
                method: method,
                endpoint: endpoint,
                statusCode: httpResponse.statusCode,
                startedAt: startedAt,
                requestPreview: requestPreview,
                responsePreview: responsePreview,
                errorMessage: apiError.localizedDescription
            )
            throw apiError
        }

        recordDebugEntry(
            method: method,
            endpoint: endpoint,
            statusCode: httpResponse.statusCode,
            startedAt: startedAt,
            requestPreview: requestPreview,
            responsePreview: responsePreview,
            errorMessage: nil
        )
        return data
    }

    private func makeRequest(method: HTTPMethod, path: String, token: String?, contentType: String = "application/json") -> URLRequest? {
        let parts = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let url = AppConfig.baseURL.appendingPathComponent(String(parts[0]))
        let finalURL: URL

        if parts.count == 2 {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.percentEncodedQuery = String(parts[1])
            guard let urlWithQuery = components?.url else {
                return nil
            }
            finalURL = urlWithQuery
        } else {
            finalURL = url
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func multipartBody(
        boundary: String,
        fieldName: String,
        fileName: String,
        mimeType: String,
        data: Data
    ) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n")
        return body
    }

    private func endpointDescription(for request: URLRequest) -> String {
        guard let url = request.url else { return "unknown" }
        var endpoint = url.path
        if let query = url.query, !query.isEmpty {
            endpoint += "?\(query)"
        }
        return endpoint
    }

    private func recordDebugEntry(
        method: String,
        endpoint: String,
        statusCode: Int?,
        startedAt: Date,
        requestPreview: String?,
        responsePreview: String?,
        errorMessage: String?
    ) {
        let durationMs = max(0, Int(Date().timeIntervalSince(startedAt) * 1_000))
        let entry = NetworkDebugEntry(
            timestamp: Date(),
            method: method,
            endpoint: endpoint,
            statusCode: statusCode,
            durationMs: durationMs,
            errorMessage: errorMessage.map(DeveloperLogSanitizer.sanitizedText),
            requestPreview: requestPreview,
            responsePreview: responsePreview
        )

        Task { @MainActor in
            NetworkDebugStore.shared.add(entry)
            let status = statusCode.map(String.init) ?? "ERR"
            DeveloperLogger.shared.log(.network, "\(method) \(endpoint) \(status) (\(durationMs) ms)")
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
