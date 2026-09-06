import Foundation
import Combine

@MainActor
final class DevicesViewModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentSessionWasClosed = false

    func load(using authManager: AuthManager) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            devices = try await authManager.fetchDevices()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unlink(_ device: Device, using authManager: AuthManager) async {
        errorMessage = nil
        do {
            let closedCurrentSession = try await authManager.unlinkDevice(deviceId: device.deviceId)
            if closedCurrentSession {
                currentSessionWasClosed = true
            } else {
                devices.removeAll { $0.deviceId == device.deviceId }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
