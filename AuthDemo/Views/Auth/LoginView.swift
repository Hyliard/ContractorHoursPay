import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var viewModel = LoginViewModel()
    @State private var showingRegister = false

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
                        Spacer(minLength: 48)

                        VStack(spacing: 24) {
                            VStack(spacing: 10) {
                                Image(systemName: "apple.books.pages.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.yellow)
                                    .frame(width: 78, height: 78)
                                    .background(Color.yellow.opacity(0.16), in: Circle())

                                VStack(spacing: 4) {
                                    Text("Bienvenido")
                                        .font(.title.bold())

                                    Text("Inicia sesión para continuar")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            VStack(spacing: 14) {
                                LoginField(systemImage: "envelope.fill") {
                                    TextField("Email", text: $viewModel.email)
                                        .textInputAutocapitalization(.never)
                                        .keyboardType(.emailAddress)
                                        .autocorrectionDisabled()
                                }

                                LoginField(systemImage: "lock.fill") {
                                    SecureField("Contraseña", text: $viewModel.password)
                                }

                                LoginField(systemImage: "iphone") {
                                    TextField("Nombre del dispositivo", text: $viewModel.deviceName)
                                        .autocorrectionDisabled()
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
                                    _ = await viewModel.login(using: authManager)
                                }
                            } label: {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text("Ingresar")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.vertical, 15)
                            .background(Color.yellow, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.black)
                            .disabled(viewModel.isLoading)

                            Button("Crear una cuenta nueva") {
                                showingRegister = true
                            }
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                        }
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
                        .padding(.horizontal, 20)

                        Spacer(minLength: 48)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .sheet(isPresented: $showingRegister) {
                RegisterView()
            }
        }
    }
}

private struct LoginField<Content: View>: View {
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
    LoginView()
        .environmentObject(AuthManager())
}
