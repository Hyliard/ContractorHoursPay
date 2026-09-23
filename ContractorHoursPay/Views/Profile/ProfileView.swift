import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var avatarMessage: String?
    @State private var avatarErrorMessage: String?
    @State private var isShowingDeveloperTools = false
    @State private var copiedMessage: String?

    @AppStorage(AppPreferenceKey.themePreference) private var themePreference = "system"
    @AppStorage(AppPreferenceKey.hideAmounts) private var hideAmounts = false
    @AppStorage(AppPreferenceKey.highlightOvertime) private var highlightOvertime = true
    @AppStorage(AppPreferenceKey.confirmBeforeArchive) private var confirmBeforeArchive = true
    @AppStorage(AppPreferenceKey.weekStartsOn) private var weekStartsOn = "monday"
    @AppStorage(AppPreferenceKey.hourFormat) private var hourFormat = "decimal"
    @AppStorage(AppPreferenceKey.preferredCurrency) private var preferredCurrency = "USD"

    private let avatarService = AvatarAPIService()
    private let themeOptions = [
        ProfilePreferenceOption(id: "system", title: "Seguir sistema"),
        ProfilePreferenceOption(id: "light", title: "Claro"),
        ProfilePreferenceOption(id: "dark", title: "Oscuro")
    ]
    private let weekStartOptions = [
        ProfilePreferenceOption(id: "monday", title: "Lunes"),
        ProfilePreferenceOption(id: "sunday", title: "Domingo")
    ]
    private let hourFormatOptions = [
        ProfilePreferenceOption(id: "decimal", title: "Decimal"),
        ProfilePreferenceOption(id: "compact", title: "Compacto")
    ]
    private let currencyOptions = ["USD", "ARS", "EUR"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        profileHeader
                        accountSection
                        preferencesSection
                        appInfoSection
                        utilitiesSection
                        dangerSection
                        logoutButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                try? await authManager.refreshCurrentUser()
            }
            .onChange(of: selectedAvatarItem) {
                Task {
                    await uploadSelectedAvatar()
                }
            }
            .sheet(isPresented: $isShowingDeveloperTools) {
                DeveloperToolsView()
                    .environmentObject(authManager)
            }
            .alert("Copiado", isPresented: Binding(
                get: { copiedMessage != nil },
                set: { if !$0 { copiedMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(copiedMessage ?? "")
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                UserAvatarView(user: authManager.currentUser, size: 104)
                    .environmentObject(authManager)

                PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
                    Image(systemName: isUploadingAvatar ? "hourglass" : "camera.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color(red: 0.12, green: 0.34, blue: 0.25), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(Color(.systemGroupedBackground), lineWidth: 3)
                        }
                }
                .disabled(isUploadingAvatar)
                .accessibilityLabel("Cambiar foto de perfil")
            }

            VStack(spacing: 5) {
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

                Label("Cuenta activa", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.12, green: 0.34, blue: 0.25))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.12, green: 0.34, blue: 0.25).opacity(0.12), in: Capsule())
                    .padding(.top, 4)
            }

            if isUploadingAvatar {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Actualizando foto...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

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
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var accountSection: some View {
        ProfileSectionCard(title: "Cuenta", systemImage: "person.text.rectangle") {
            ProfileInfoRow(title: "Nombre", value: authManager.currentUser?.name ?? "No disponible")
            ProfileInfoRow(title: "Email", value: authManager.currentUser?.email ?? "No disponible")
            ProfileInfoRow(title: "Estado de sesión", value: authManager.isAuthenticated ? "Sesión activa" : "Sin sesión")
            if let createdAt = authManager.currentUser?.createdAt {
                ProfileInfoRow(title: "Creada", value: createdAt)
            }
        }
    }

    private var preferencesSection: some View {
        ProfileSectionCard(title: "Preferencias", systemImage: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Apariencia")
                    .font(.subheadline.weight(.semibold))
                Picker("Tema", selection: $themePreference) {
                    ForEach(themeOptions) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Tema")
            }

            Divider()

            Toggle(isOn: $hideAmounts) {
                PreferenceLabel(
                    title: "Ocultar montos en la app",
                    description: "Reduce exposición visual de saldos y cobros."
                )
            }
            .accessibilityLabel("Ocultar montos en la app")

            Divider()

            Toggle(isOn: $highlightOvertime) {
                PreferenceLabel(
                    title: "Resaltar horas extra",
                    description: "Deja lista la preferencia para destacar registros especiales."
                )
            }
            .accessibilityLabel("Resaltar horas extra")

            Divider()

            Toggle(isOn: $confirmBeforeArchive) {
                PreferenceLabel(
                    title: "Confirmar antes de archivar",
                    description: "Mantiene una confirmación adicional para acciones sensibles."
                )
            }
            .accessibilityLabel("Confirmar antes de archivar")

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Primer día de la semana")
                    .font(.subheadline.weight(.semibold))
                Picker("Primer día de la semana", selection: $weekStartsOn) {
                    ForEach(weekStartOptions) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Formato de horas")
                    .font(.subheadline.weight(.semibold))
                Picker("Formato de horas", selection: $hourFormat) {
                    Text("Decimal (8.5 h)").tag("decimal")
                    Text("Compacto (8 h 30 min)").tag("compact")
                }
                .pickerStyle(.menu)
            }

            Divider()

            Picker("Moneda preferida", selection: $preferredCurrency) {
                ForEach(currencyOptions, id: \.self) { currency in
                    Text(currency).tag(currency)
                }
            }
            .accessibilityLabel("Moneda preferida para destacar")
        }
    }

    private var appInfoSection: some View {
        ProfileSectionCard(title: "Aplicación", systemImage: "app.badge") {
            ProfileInfoRow(title: "Nombre", value: appName)
            ProfileInfoRow(title: "Versión", value: appVersion)
            ProfileInfoRow(title: "Build", value: buildNumber)
            ProfileInfoRow(title: "Bundle ID", value: bundleID)
            ProfileInfoRow(title: "Entorno", value: AppConfig.environmentName)
            ProfileInfoRow(title: "Base URL", value: AppConfig.baseURL.absoluteString)
            ProfileInfoRow(title: "iOS", value: UIDevice.current.systemVersion)
            ProfileInfoRow(title: "Dispositivo", value: UIDevice.current.model)
        }
    }

    private var utilitiesSection: some View {
        ProfileSectionCard(title: "Soporte y utilidades", systemImage: "wrench.and.screwdriver") {
            Button {
                isShowingDeveloperTools = true
            } label: {
                ProfileActionRow(
                    systemImage: "ladybug",
                    title: "Herramientas de desarrollo",
                    description: "Revisá red, backend, sesión y logs.",
                    tint: .orange
                )
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.leading, 58)

            NavigationLink {
                ChangePasswordView()
            } label: {
                ProfileActionRow(
                    systemImage: "lock.rotation",
                    title: "Cambiar contraseña",
                    description: "Actualizá tu clave de acceso.",
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
                    description: "Consultá tus sesiones activas.",
                    tint: .teal
                )
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.leading, 58)

            Button {
                UIPasteboard.general.string = AppConfig.baseURL.absoluteString
                copiedMessage = "Base URL copiada."
            } label: {
                ProfileActionRow(
                    systemImage: "link",
                    title: "Copiar Base URL",
                    description: AppConfig.baseURL.absoluteString,
                    tint: .blue
                )
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.leading, 58)

            Button {
                UIPasteboard.general.string = "\(appName) \(appVersion) (\(buildNumber))"
                copiedMessage = "Versión y build copiados."
            } label: {
                ProfileActionRow(
                    systemImage: "doc.on.doc",
                    title: "Copiar versión/build",
                    description: "\(appVersion) (\(buildNumber))",
                    tint: .gray
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var dangerSection: some View {
        ProfileSectionCard(title: "Cuenta", systemImage: "exclamationmark.triangle") {
            NavigationLink {
                DeleteAccountView()
            } label: {
                ProfileActionRow(
                    systemImage: "trash.fill",
                    title: "Eliminar cuenta",
                    description: "Borrá tu cuenta de forma permanente.",
                    tint: .red
                )
            }
            .buttonStyle(.plain)
        }
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
        .accessibilityLabel("Cerrar sesión")
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
}

private struct ProfilePreferenceOption: Identifiable {
    let id: String
    let title: String
}

private struct ProfileSectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    private let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
                content
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ProfileInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 16)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
        }
        .padding(.vertical, 8)
    }
}

private struct PreferenceLabel: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            Text(description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
