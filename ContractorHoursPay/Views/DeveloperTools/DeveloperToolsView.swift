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
                Section("Network") {
                    NavigationLink {
                        NetworkDebugView()
                    } label: {
                        Label("Network Debug", systemImage: "network")
                    }
                }

                Section("Backend") {
                    LabeledContent("API Health", value: healthStatus.title)
                    LabeledContent("Base URL", value: AppConfig.baseURL.absoluteString)
                    LabeledContent("Latency", value: healthLatencyText)

                    if let healthCheckedAt {
                        LabeledContent("Last Test", value: healthCheckedAt.formatted(.dateTime.hour().minute().second()))
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
                            Label("Test API Health", systemImage: "stethoscope")
                        }
                    }
                    .disabled(isTestingHealth)
                }

                Section("Auth") {
                    LabeledContent("Session", value: authManager.isAuthenticated ? "Authenticated" : "Not authenticated")
                    LabeledContent("Current User", value: currentUserText)
                    LabeledContent("Token Status", value: authManager.token == nil ? "Missing" : "Present")
                }

                Section("Logs") {
                    NavigationLink {
                        ApplicationLogsView()
                    } label: {
                        Label("Application Logs", systemImage: "doc.text.magnifyingglass")
                    }
                }

                Section("App Info") {
                    LabeledContent("App Name", value: appName)
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build", value: buildNumber)
                    LabeledContent("Bundle ID", value: bundleID)
                    LabeledContent("iOS Version", value: UIDevice.current.systemVersion)
                    LabeledContent("Device Model", value: UIDevice.current.model)
                    LabeledContent("Environment", value: AppConfig.environmentName)
                    LabeledContent("Base URL", value: AppConfig.baseURL.absoluteString)
                }
            }
            .navigationTitle("Developer Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var currentUserText: String {
        guard let user = authManager.currentUser else { return "None" }
        return "\(user.name) • \(user.email)"
    }

    private var healthLatencyText: String {
        guard let healthLatencyMs else { return "N/A" }
        return "\(healthLatencyMs) ms"
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "ContractorHoursPay"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
    }

    private var bundleID: String {
        Bundle.main.bundleIdentifier ?? "N/A"
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
            "Not tested"
        case .online:
            "Online"
        case .offline:
            "Offline"
        }
    }
}
