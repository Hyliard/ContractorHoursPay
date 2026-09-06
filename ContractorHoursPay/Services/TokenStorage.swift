import Foundation

/// Guarda el token y el deviceId localmente para no tener que loguearse en
/// cada arranque de la app.
///
/// Usa UserDefaults por simplicidad, ya que esta es una app de práctica.
/// En una app real conviene usar el Keychain, porque UserDefaults no cifra
/// los datos guardados.
struct TokenStorage {
    private let defaults = UserDefaults.standard
    private let tokenKey = "auth.token"
    private let deviceIdKey = "auth.deviceId"

    var token: String? {
        get { defaults.string(forKey: tokenKey) }
        nonmutating set { defaults.set(newValue, forKey: tokenKey) }
    }

    var deviceId: String? {
        get { defaults.string(forKey: deviceIdKey) }
        nonmutating set { defaults.set(newValue, forKey: deviceIdKey) }
    }

    func clear() {
        defaults.removeObject(forKey: tokenKey)
        defaults.removeObject(forKey: deviceIdKey)
    }
}
