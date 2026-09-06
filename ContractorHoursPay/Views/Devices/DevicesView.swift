import SwiftUI

struct DevicesView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var viewModel = DevicesViewModel()

    var body: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            ForEach(viewModel.devices) { device in
                DeviceRowView(device: device) {
                    Task {
                        await viewModel.unlink(device, using: authManager)
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.devices.isEmpty {
                ProgressView()
            } else if !viewModel.isLoading && viewModel.devices.isEmpty {
                ContentUnavailableView("Sin dispositivos", systemImage: "iphone.slash")
            }
        }
        .navigationTitle("Dispositivos")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(using: authManager)
        }
        .refreshable {
            await viewModel.load(using: authManager)
        }
    }
}

#Preview {
    NavigationStack {
        DevicesView()
            .environmentObject(AuthManager())
    }
}
