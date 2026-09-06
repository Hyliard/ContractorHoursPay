import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authManager: AuthManager

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
    }
}

#Preview {
    RootView()
        .environmentObject(AuthManager())
}
