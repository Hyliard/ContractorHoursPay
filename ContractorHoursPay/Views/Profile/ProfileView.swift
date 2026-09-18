import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var avatarMessage: String?
    @State private var avatarErrorMessage: String?

    private let avatarService = AvatarAPIService()

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
            .onChange(of: selectedAvatarItem) {
                Task {
                    await uploadSelectedAvatar()
                }
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            UserAvatarView(user: authManager.currentUser, size: 92)
                .environmentObject(authManager)

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

            PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
                if isUploadingAvatar {
                    ProgressView()
                } else {
                    Label("Cambiar foto", systemImage: "camera")
                        .font(.subheadline.weight(.medium))
                }
            }
            .disabled(isUploadingAvatar)
            .foregroundStyle(.primary)
            .padding(.top, 4)
            .accessibilityLabel("Cambiar foto de perfil")

            if let avatarMessage {
                Text(avatarMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let avatarErrorMessage {
                Text(avatarErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 8)
    }

    private func uploadSelectedAvatar() async {
        guard let selectedAvatarItem else { return }
        avatarMessage = nil
        avatarErrorMessage = nil
        isUploadingAvatar = true
        defer {
            isUploadingAvatar = false
            self.selectedAvatarItem = nil
        }

        do {
            guard let token = authManager.token else { throw APIError.notAuthenticated }
            guard let originalData = try await selectedAvatarItem.loadTransferable(type: Data.self) else {
                avatarErrorMessage = "No se pudo leer la imagen seleccionada."
                return
            }

            let prepared = try prepareAvatarData(from: originalData)
            let oldAvatarUrl = authManager.currentUser?.avatarUrl
            _ = try await avatarService.uploadAvatar(
                data: prepared.data,
                mimeType: prepared.mimeType,
                fileExtension: prepared.fileExtension,
                token: token
            )
            AvatarImageCache.removeImage(forKey: oldAvatarUrl)
            try await authManager.refreshCurrentUser()
            avatarMessage = "Foto actualizada."
        } catch {
            avatarErrorMessage = avatarUploadMessage(for: error)
        }
    }

    private func prepareAvatarData(from data: Data) throws -> (data: Data, mimeType: String, fileExtension: String) {
        guard !data.isEmpty, let image = UIImage(data: data) else {
            throw APIError.server(message: "La imagen seleccionada no es válida.", statusCode: 400)
        }

        let resizedImage = image.resizedForAvatar(maxDimension: 1_200)
        var compression: CGFloat = 0.82
        var output = resizedImage.jpegData(compressionQuality: compression)

        while let currentOutput = output, currentOutput.count > 5 * 1_024 * 1_024, compression > 0.35 {
            compression -= 0.12
            output = resizedImage.jpegData(compressionQuality: compression)
        }

        guard let output, output.count <= 5 * 1_024 * 1_024 else {
            throw APIError.server(message: "La imagen es demasiado grande.", statusCode: 413)
        }

        return (output, "image/jpeg", "jpg")
    }

    private func avatarUploadMessage(for error: Error) -> String {
        if case APIError.server(_, let statusCode) = error {
            switch statusCode {
            case 413:
                return "La imagen es demasiado grande."
            case 415:
                return "Formato de imagen no compatible."
            case 400:
                return "La imagen seleccionada no es válida."
            default:
                break
            }
        }
        return error.localizedDescription
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

private extension UIImage {
    func resizedForAvatar(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else {
            return normalized()
        }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
}
