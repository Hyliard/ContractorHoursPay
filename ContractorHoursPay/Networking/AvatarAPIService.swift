import Foundation

struct AvatarAPIService {
    private let client: APIClient
    private let maxSize = 5 * 1_024 * 1_024

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func uploadAvatar(data: Data, mimeType: String, fileExtension: String, token: String) async throws -> User {
        guard !data.isEmpty else {
            throw APIError.server(message: "La imagen seleccionada no es válida.", statusCode: 400)
        }
        guard data.count <= maxSize else {
            throw APIError.server(message: "La imagen es demasiado grande.", statusCode: 413)
        }
        guard ["image/jpeg", "image/png", "image/webp"].contains(mimeType) else {
            throw APIError.server(message: "Formato de imagen no compatible.", statusCode: 415)
        }

        let response: AvatarUploadResponse = try await client.sendMultipart(
            path: "api/users/me/avatar",
            fieldName: "avatar",
            fileName: "avatar-\(UUID().uuidString).\(fileExtension)",
            mimeType: mimeType,
            data: data,
            token: token
        )
        return response.user
    }

    func fetchAvatar(token: String) async throws -> Data {
        try await client.sendData(method: .get, path: "api/users/me/avatar", token: token)
    }
}

private struct AvatarUploadResponse: Decodable {
    let user: User
}
