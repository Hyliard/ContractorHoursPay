import Foundation

/// Envoltorio sobre APIClient con un método por cada endpoint de la API,
/// usando los mismos nombres de campos que espera el backend.
struct AuthAPIService {
    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func register(name: String, email: String, password: String) async throws -> User {
        struct RegisterRequest: Encodable {
            let name: String
            let email: String
            let password: String
        }
        struct RegisterResponse: Decodable { let user: User }

        let body = RegisterRequest(name: name, email: email, password: password)
        let response: RegisterResponse = try await client.send(method: .post, path: "api/auth/register", body: body)
        return response.user
    }

    func login(email: String, password: String, deviceName: String) async throws -> (token: String, deviceId: String, user: User) {
        struct LoginRequest: Encodable {
            let email: String
            let password: String
            let deviceName: String
        }
        struct LoginResponse: Decodable {
            let token: String
            let deviceId: String
            let user: User
        }

        let body = LoginRequest(email: email, password: password, deviceName: deviceName)
        let response: LoginResponse = try await client.send(method: .post, path: "api/auth/login", body: body)
        return (response.token, response.deviceId, response.user)
    }

    func me(token: String) async throws -> User {
        struct MeResponse: Decodable { let user: User }
        let response: MeResponse = try await client.send(method: .get, path: "api/auth/me", token: token)
        return response.user
    }

    func changePassword(currentPassword: String, newPassword: String, token: String) async throws -> String {
        struct ChangePasswordRequest: Encodable {
            let currentPassword: String
            let newPassword: String
        }
        struct MessageResponse: Decodable { let message: String }

        let body = ChangePasswordRequest(currentPassword: currentPassword, newPassword: newPassword)
        let response: MessageResponse = try await client.send(method: .post, path: "api/auth/change-password", body: body, token: token)
        return response.message
    }

    func logout(token: String) async throws {
        try await client.sendNoContent(method: .delete, path: "api/auth/session", token: token)
    }

    func devices(token: String) async throws -> [Device] {
        struct DevicesResponse: Decodable { let devices: [Device] }
        let response: DevicesResponse = try await client.send(method: .get, path: "api/devices", token: token)
        return response.devices
    }

    func unlinkDevice(deviceId: String, token: String) async throws -> (message: String, currentSessionClosed: Bool) {
        struct UnlinkResponse: Decodable {
            let message: String
            let currentSessionClosed: Bool
        }
        let response: UnlinkResponse = try await client.send(method: .delete, path: "api/devices/\(deviceId)", token: token)
        return (response.message, response.currentSessionClosed)
    }

    func deleteAccount(password: String, token: String) async throws {
        struct DeleteAccountRequest: Encodable { let password: String }
        let body = DeleteAccountRequest(password: password)
        try await client.sendNoContent(method: .delete, path: "api/users/me", body: body, token: token)
    }
}
