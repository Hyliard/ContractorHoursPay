import Foundation

/// Refleja el formato de error que devuelve la API:
/// { "error": { "message": "...", "statusCode": 400 } }
struct APIErrorPayload: Decodable {
    struct Detail: Decodable {
        let message: String
        let statusCode: Int
    }
    let error: Detail
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(message: String, statusCode: Int)
    case decoding
    case network(String)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "La URL de la API no es válida."
        case .invalidResponse:
            return "El servidor devolvió una respuesta inesperada."
        case .server(let message, _):
            return message
        case .decoding:
            return "No se pudo interpretar la respuesta del servidor."
        case .network(let description):
            return description
        case .notAuthenticated:
            return "Tu sesión ya no es válida. Iniciá sesión de nuevo."
        }
    }
}
