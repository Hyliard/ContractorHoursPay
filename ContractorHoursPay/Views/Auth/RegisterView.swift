import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var viewModel = RegisterViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.yellow.opacity(0.38),
                        Color(.systemBackground),
                        Color.orange.opacity(0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                    .ignoresSafeArea()

                Circle()
                    .fill(Color.yellow.opacity(0.28))
                    .frame(width: 220, height: 220)
                    .blur(radius: 28)
                    .offset(x: -120, y: -260)

                Circle()
                    .fill(Color.orange.opacity(0.18))
                    .frame(width: 260, height: 260)
                    .blur(radius: 34)
                    .offset(x: 140, y: 260)

                ScrollView {
                    VStack {
                        Spacer(minLength: 40)

                        VStack(spacing: 24) {
                            VStack(spacing: 10) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.yellow)
                                    .frame(width: 78, height: 78)
                                    .background(Color.yellow.opacity(0.16), in: Circle())

                                VStack(spacing: 4) {
                                    Text("Crear cuenta")
                                        .font(.title.bold())

                                    Text("Completa tus datos para comenzar")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }

                            VStack(spacing: 14) {
                                RegisterField(systemImage: "person.fill") {
                                    TextField("Nombre", text: $viewModel.name)
                                        .autocorrectionDisabled()
                                }

                                RegisterField(systemImage: "envelope.fill") {
                                    TextField("Email", text: $viewModel.email)
                                        .textInputAutocapitalization(.never)
                                        .keyboardType(.emailAddress)
                                        .autocorrectionDisabled()
                                }

                                RegisterField(systemImage: "lock.fill") {
                                    SecureField("Contraseña (mín. 8 caracteres)", text: $viewModel.password)
                                }
                            }

                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }

                            Button {
                                Task {
                                    await viewModel.register(using: authManager)
                                }
                            } label: {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text("Registrarme")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.vertical, 15)
                            .background(Color.yellow, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.black)
                            .disabled(viewModel.isLoading)
                        }
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
                        .padding(.horizontal, 20)

                        Spacer(minLength: 40)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Crear cuenta")
            .navigationBarTitleDisplayMode(.inline)
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
}

private struct RegisterField<Content: View>: View {
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            content
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthManager())
}
