import Foundation

enum Config {
    /// En el Simulador de iOS, "localhost" apunta directo a tu Mac, así que
    /// esta URL funciona mientras corras la API con `npm run dev`.
    ///
    /// Si probás en un dispositivo físico (iPhone real), "localhost" ya no
    /// sirve porque apuntaría al propio dispositivo. Reemplazá esto por la
    /// IP de tu Mac en la red local, por ejemplo:
    ///   static let baseURL = URL(string: "http://192.168.1.50:3000")!
    /// y agregá una excepción de App Transport Security en Info.plist para
    /// ese dominio, ya que no es HTTPS.
    static let baseURL = URL(string: "http://100.87.169.91:3004")!
}
