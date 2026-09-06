import Foundation
import Combine

/// Fuente única de verdad para el estado de autenticación de la app.
/// Las vistas leen `isAuthenticated` y `currentUser`; los ViewModels llaman
/// a sus métodos para ejecutar acciones contra la API.
@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isRestoringSession = true

    private(set) var token: String?
    private(set) var deviceId: String?

    private let service: AuthAPIService
    private var storage: TokenStorage

    init(service: AuthAPIService, storage: TokenStorage) {
        self.service = service
        self.storage = storage
    }

    convenience init() {
        self.init(service: AuthAPIService(), storage: TokenStorage())
    }

    /// Se llama al arrancar la app: si hay un token guardado, verifica que
    /// siga siendo válido contra /api/auth/me antes de dar por autenticado
    /// al usuario.
    func restoreSession() async {
        defer { isRestoringSession = false }
        guard let storedToken = storage.token else { return }
        token = storedToken
        deviceId = storage.deviceId
        do {
            currentUser = try await service.me(token: storedToken)
            isAuthenticated = true
        } catch {
            // El token guardado ya no sirve (expiró, se cerró la sesión,
            // se desvinculó el dispositivo, etc.)
            clearSession()
        }
    }

    func register(name: String, email: String, password: String) async throws {
        _ = try await service.register(name: name, email: email, password: password)
    }

    func login(email: String, password: String, deviceName: String) async throws {
        let result = try await service.login(email: email, password: password, deviceName: deviceName)
        token = result.token
        deviceId = result.deviceId
        currentUser = result.user
        storage.token = result.token
        storage.deviceId = result.deviceId
        isAuthenticated = true
    }

    func refreshCurrentUser() async throws {
        guard let token else { throw APIError.notAuthenticated }
        currentUser = try await service.me(token: token)
    }

    func changePassword(currentPassword: String, newPassword: String) async throws -> String {
        guard let token else { throw APIError.notAuthenticated }
        let message = try await service.changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
            token: token
        )
        // El backend revoca todas las sesiones al cambiar la contraseña,
        // así que la sesión local también deja de ser válida.
        clearSession()
        return message
    }

    func fetchDevices() async throws -> [Device] {
        guard let token else { throw APIError.notAuthenticated }
        return try await service.devices(token: token)
    }

    /// Devuelve `true` si el dispositivo desvinculado era el actual (en cuyo
    /// caso la sesión local también se cierra).
    func unlinkDevice(deviceId targetDeviceId: String) async throws -> Bool {
        guard let token else { throw APIError.notAuthenticated }
        let result = try await service.unlinkDevice(deviceId: targetDeviceId, token: token)
        if result.currentSessionClosed {
            clearSession()
        }
        return result.currentSessionClosed
    }

    func logout() async {
        if let token {
            try? await service.logout(token: token)
        }
        clearSession()
    }

    func deleteAccount(password: String) async throws {
        guard let token else { throw APIError.notAuthenticated }
        try await service.deleteAccount(password: password, token: token)
        clearSession()
    }

    private func clearSession() {
        token = nil
        deviceId = nil
        currentUser = nil
        isAuthenticated = false
        storage.clear()
    }
}
