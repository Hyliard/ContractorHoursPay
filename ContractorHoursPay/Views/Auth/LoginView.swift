import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var viewModel = LoginViewModel()
    @State private var showingRegister = false
    @State private var isPasswordVisible = false
    @FocusState private var focusedField: LoginFocusedField?

    private let accent = Color(red: 0.12, green: 0.34, blue: 0.25)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    LoginHero(accent: accent)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tu trabajo, bajo control")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Text("Registra tus horas, organiza tus proyectos y lleva el control de tus ingresos.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 14) {
                        LoginField(title: "Email", systemImage: "envelope", accent: accent) {
                            TextField("Email", text: $viewModel.email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .submitLabel(.next)
                                .focused($focusedField, equals: .email)
                                .onSubmit {
                                    focusedField = .password
                                }
                                .accessibilityLabel("Email")
                        }

                        LoginField(title: "Contraseña", systemImage: "lock", accent: accent) {
                            PasswordInput(
                                placeholder: "Contraseña",
                                text: $viewModel.password,
                                isVisible: $isPasswordVisible,
                                focusedField: $focusedField,
                                focusValue: .password
                            )
                        }

                        LoginField(title: "Nombre del dispositivo", systemImage: "iphone", accent: accent) {
                            TextField("Nombre del dispositivo", text: $viewModel.deviceName)
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                                .focused($focusedField, equals: .deviceName)
                                .onSubmit {
                                    focusedField = nil
                                }
                                .accessibilityLabel("Nombre del dispositivo")
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .accessibilityLabel("Error de inicio de sesión: \(errorMessage)")
                    }

                    PrimaryLoginButton(isLoading: viewModel.isLoading, accent: accent) {
                        focusedField = nil
                        Task {
                            _ = await viewModel.login(using: authManager)
                        }
                    }

                    registerPrompt
                }
                .padding(.horizontal, 22)
                .padding(.top, 28)
                .padding(.bottom, 36)
            }
            .background(Color(.systemBackground))
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $showingRegister) {
                RegisterView()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Text("ContractorHours")
                    .foregroundStyle(.primary)
                Text("Pay")
                    .foregroundStyle(accent)
            }
            .font(.largeTitle)
            .fontWeight(.bold)
            .minimumScaleFactor(0.78)
            .lineLimit(1)
            .accessibilityLabel("ContractorHoursPay")

            Text("Horas · Proyectos · Pagos")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var registerPrompt: some View {
        HStack(spacing: 4) {
            Text("¿No tienes una cuenta?")
                .foregroundStyle(.secondary)

            Button {
                showingRegister = true
            } label: {
                Text("Crear cuenta")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(accent)
            .accessibilityLabel("Crear cuenta")
        }
        .font(.footnote)
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }
}

private enum LoginFocusedField: Hashable {
    case email
    case password
    case deviceName
}

private struct LoginField<Content: View>: View {
    let title: String
    let systemImage: String
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(accent)
                    .frame(width: 22)

                content
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct PasswordInput: View {
    let placeholder: String
    @Binding var text: String
    @Binding var isVisible: Bool
    var focusedField: FocusState<LoginFocusedField?>.Binding
    let focusValue: LoginFocusedField

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .focused(focusedField, equals: focusValue)
            .onSubmit {
                focusedField.wrappedValue = nil
            }
            .accessibilityLabel(placeholder)

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isVisible ? "Ocultar contraseña" : "Mostrar contraseña")
        }
    }
}

private struct LoginHero: View {
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                // Placeholder temporal. Cuando exista el asset, reemplazar por:
                // Image("contractor-login-hero").resizable().aspectRatio(contentMode: .fill)
                LinearGradient(
                    colors: [
                        accent.opacity(0.18),
                        Color(.secondarySystemBackground),
                        accent.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .bottom, spacing: 10) {
                        HeroBar(height: 64, accent: accent.opacity(0.82))
                        HeroBar(height: 92, accent: accent.opacity(0.62))
                        HeroBar(height: 126, accent: accent.opacity(0.42))
                    }
                    .frame(height: 132, alignment: .bottom)

                    HStack(spacing: 8) {
                        Label("Horas", systemImage: "clock")
                        Label("Clientes", systemImage: "person.2")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .frame(width: proxy.size.width, height: heroHeight(for: proxy.size.width))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
        .frame(height: 246)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ilustración de control de horas, clientes y pagos")
    }

    private func heroHeight(for width: CGFloat) -> CGFloat {
        min(max(width * 0.66, 220), 280)
    }
}

private struct HeroBar: View {
    let height: CGFloat
    let accent: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(accent)
            .frame(width: 42, height: height)
    }
}

private struct PrimaryLoginButton: View {
    let isLoading: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
            } else {
                Text("Ingresar")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 15)
        .background(accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .foregroundStyle(.white)
        .disabled(isLoading)
        .accessibilityLabel(isLoading ? "Ingresando" : "Ingresar")
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
