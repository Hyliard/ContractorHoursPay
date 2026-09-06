import SwiftUI

struct DeviceRowView: View {
    let device: Device
    let onUnlink: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(device.deviceName)
                        .font(.headline)
                    if device.isCurrentDevice {
                        Text("Este dispositivo")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.tint.opacity(0.15))
                            .foregroundStyle(.tint)
                            .clipShape(Capsule())
                    }
                }
                Text("Último acceso: \(device.lastLoginAt)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                onUnlink()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }
}

#Preview {
    DeviceRowView(
        device: Device(deviceId: "1", deviceName: "iPhone de prueba", createdAt: "", lastLoginAt: "", isCurrentDevice: true),
        onUnlink: {}
    )
}
