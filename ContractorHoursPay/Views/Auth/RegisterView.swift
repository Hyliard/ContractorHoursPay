import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var viewModel = RegisterViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var isPasswordVisible = false
    @FocusState private var focusedField: RegisterFocusedField?

    private let accent = Color(red: 0.12, green: 0.34, blue: 0.25)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    VStack(spacing: 14) {
                        RegisterField(title: "Nombre", systemImage: "person", accent: accent) {
                            TextField("Nombre", text: $viewModel.name)
                                .autocorrectionDisabled()
                                .submitLabel(.next)
                                .focused($focusedField, equals: .name)
                                .onSubmit {
                                    focusedField = .email
                                }
                                .accessibilityLabel("Nombre")
                        }

                        RegisterField(title: "Email", systemImage: "envelope", accent: accent) {
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

                        RegisterField(title: "Contraseña", systemImage: "lock", accent: accent) {
                            RegisterPasswordInput(
                                placeholder: "Contraseña (mín. 8 caracteres)",
                                text: $viewModel.password,
                                isVisible: $isPasswordVisible,
                                focusedField: $focusedField,
                                focusValue: .password
                            )
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
                            .accessibilityLabel("Error de registro: \(errorMessage)")
                    }

                    Button {
                        focusedField = nil
                        Task {
                            await viewModel.register(using: authManager)
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Crear cuenta")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 15)
                    .background(accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel(viewModel.isLoading ? "Creando cuenta" : "Crear cuenta")

                    loginPrompt
                }
                .padding(.horizontal, 22)
                .padding(.top, 28)
                .padding(.bottom, 36)
            }
            .background(Color(.systemBackground))
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .alert("Cuenta creada", isPresented: $viewModel.didRegister) {
                Button("Iniciar sesión") { dismiss() }
            } message: {
                Text("Ya podés iniciar sesión con tu nueva cuenta.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Crear tu cuenta")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text("Empieza a registrar tus horas, proyectos e ingresos.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
        }
        .padding(.top, 8)
    }

    private var loginPrompt: some View {
        HStack(spacing: 4) {
            Text("¿Ya tienes una cuenta?")
                .foregroundStyle(.secondary)

            Button {
                dismiss()
            } label: {
                Text("Iniciar sesión")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(accent)
            .accessibilityLabel("Iniciar sesión")
        }
        .font(.footnote)
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }
}

private enum RegisterFocusedField: Hashable {
    case name
    case email
    case password
}

private struct RegisterField<Content: View>: View {
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

private struct RegisterPasswordInput: View {
    let placeholder: String
    @Binding var text: String
    @Binding var isVisible: Bool
    var focusedField: FocusState<RegisterFocusedField?>.Binding
    let focusValue: RegisterFocusedField

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
            .accessibilityLabel("Contraseña, mínimo 8 caracteres")

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

#Preview {
    RegisterView()
        .environmentObject(AuthManager())
}
