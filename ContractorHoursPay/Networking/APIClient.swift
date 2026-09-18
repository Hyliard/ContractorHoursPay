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
        return try decode(data)
    }

    // MARK: - Sin body, con respuesta decodificada

    func send<Response: Decodable>(
        method: HTTPMethod,
        path: String,
        token: String? = nil
    ) async throws -> Response {
        let data = try await sendRaw(method: method, path: path, body: Optional<EmptyBody>.none, token: token)
        return try decode(data)
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

        let responseData = try await send(request)
        return try decode(responseData)
    }

    // MARK: - Privados

    private func decode<Response: Decodable>(_ data: Data) throws -> Response {
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
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

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIError.notAuthenticated
            }
            if let errorPayload = try? JSONDecoder().decode(APIErrorPayload.self, from: data) {
                throw APIError.server(message: errorPayload.error.message, statusCode: httpResponse.statusCode)
            }
            throw APIError.server(message: "Ocurrió un error inesperado.", statusCode: httpResponse.statusCode)
        }

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
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
