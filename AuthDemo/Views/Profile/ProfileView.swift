import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        profileHeader
                        securityCard
                        accountCard
                        logoutButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Perfil")
            .refreshable {
                try? await authManager.refreshCurrentUser()
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 92, height: 92)
                .background(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .shadow(color: .blue.opacity(0.25), radius: 14, x: 0, y: 8)

            VStack(spacing: 4) {
                Text(authManager.currentUser?.name ?? "Usuario")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(authManager.currentUser?.email ?? "Email no disponible")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            Text("Bienvenido a tu espacio personal")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 8)
    }

    private var securityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Seguridad")
                .font(.headline)

            VStack(spacing: 0) {
                NavigationLink {
                    ChangePasswordView()
                } label: {
                    ProfileActionRow(
                        systemImage: "lock.rotation",
                        title: "Cambiar contraseña",
                        description: "Actualizá tu clave de acceso",
                        tint: .indigo
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 58)

                NavigationLink {
                    DevicesView()
                } label: {
                    ProfileActionRow(
                        systemImage: "iphone.gen3",
                        title: "Dispositivos vinculados",
                        description: "Consultá tus sesiones activas",
                        tint: .teal
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Cuenta")
                .font(.headline)

            NavigationLink {
                DeleteAccountView()
            } label: {
                ProfileActionRow(
                    systemImage: "trash.fill",
                    title: "Eliminar cuenta",
                    description: "Borrá tu cuenta de forma permanente",
                    tint: .red
                )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
    }

    private var logoutButton: some View {
        Button(role: .destructive) {
            Task {
                await authManager.logout()
            }
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.headline)

                Text("Cerrar sesión")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.red)
            .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
}

private struct ProfileActionRow: View {
    let systemImage: String
    let title: String
    let description: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
}
