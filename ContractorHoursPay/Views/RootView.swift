import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authManager: AuthManager
    @AppStorage(AppPreferenceKey.themePreference) private var themePreference = "system"

    var body: some View {
        Group {
            if authManager.isRestoringSession {
                ProgressView("Cargando…")
            } else if authManager.isAuthenticated {
                DashboardView()
            } else {
                LoginView()
            }
        }
        .task {
            await authManager.restoreSession()
        }
        .preferredColorScheme(AppPreferences.colorScheme(for: themePreference))
    }
}

#Preview {
    RootView()
        .environmentObject(AuthManager())
}
