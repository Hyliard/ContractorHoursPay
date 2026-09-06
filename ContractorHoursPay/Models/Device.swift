import Foundation

struct Device: Codable, Identifiable, Equatable {
    let deviceId: String
    let deviceName: String
    let createdAt: String
    let lastLoginAt: String
    let isCurrentDevice: Bool

    var id: String { deviceId }
}
