import SwiftUI
import UIKit

struct DeveloperToolsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var healthStatus: HealthStatus = .notTested
    @State private var healthLatencyMs: Int?
    @State private var healthCheckedAt: Date?
    @State private var healthError: String?
    @State private var isTestingHealth = false

    private let apiClient = APIClient()

    var body: some View {
        NavigationStack {
            List {
                Section("Red") {
                    NavigationLink {
                        NetworkDebugView()
                    } label: {
                        Label("Depuración de red", systemImage: "network")
                    }
                }

                Section("Backend") {
                    LabeledContent("Estado de API", value: healthStatus.title)
                    LabeledContent("Base URL", value: AppConfig.baseURL.absoluteString)
                    LabeledContent("Latencia", value: healthLatencyText)

                    if let healthCheckedAt {
                        LabeledContent("Última prueba", value: healthCheckedAt.formatted(.dateTime.hour().minute().second()))
                    }

                    if let healthError {
                        Text(healthError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task {
                            await testAPIHealth()
                        }
                    } label: {
                        if isTestingHealth {
                            ProgressView()
                        } else {
                            Label("Probar estado de API", systemImage: "stethoscope")
                        }
                    }
                    .disabled(isTestingHealth)
                }

                Section("Autenticación") {
                    LabeledContent("Sesión", value: authManager.isAuthenticated ? "Autenticada" : "Sin autenticar")
                    LabeledContent("Usuario actual", value: currentUserText)
                    LabeledContent("Estado del token", value: authManager.token == nil ? "Ausente" : "Disponible")
                }

                Section("Logs") {
                    NavigationLink {
                        ApplicationLogsView()
                    } label: {
                        Label("Logs de la aplicación", systemImage: "doc.text.magnifyingglass")
                    }
                }

                Section("Información de la app") {
                    LabeledContent("Nombre de la app", value: appName)
                    LabeledContent("Versión", value: appVersion)
                    LabeledContent("Build", value: buildNumber)
                    LabeledContent("Bundle ID", value: bundleID)
                    LabeledContent("Versión de iOS", value: UIDevice.current.systemVersion)
                    LabeledContent("Modelo del dispositivo", value: UIDevice.current.model)
                    LabeledContent("Entorno", value: AppConfig.environmentName)
                    LabeledContent("Base URL", value: AppConfig.baseURL.absoluteString)
                }
            }
            .navigationTitle("Herramientas de desarrollo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Listo") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var currentUserText: String {
        guard let user = authManager.currentUser else { return "Ninguno" }
        return "\(user.name) • \(user.email)"
    }

    private var healthLatencyText: String {
        guard let healthLatencyMs else { return "N/D" }
        return "\(healthLatencyMs) ms"
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "ContractorHoursPay"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/D"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/D"
    }

    private var bundleID: String {
        Bundle.main.bundleIdentifier ?? "N/D"
    }

    private func testAPIHealth() async {
        isTestingHealth = true
        healthError = nil
        healthCheckedAt = Date()
        let startedAt = Date()

        do {
            _ = try await apiClient.sendData(method: .get, path: "api/health")
            healthLatencyMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
            healthStatus = .online
        } catch {
            healthLatencyMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
            healthStatus = .offline
            healthError = error.localizedDescription
        }

        isTestingHealth = false
    }
}

private enum HealthStatus {
    case notTested
    case online
    case offline

    var title: String {
        switch self {
        case .notTested:
            "Sin probar"
        case .online:
            "En línea"
        case .offline:
            "Sin conexión"
        }
    }
}
