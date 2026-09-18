import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var workLogsViewModel = WorkLogsViewModel()
    @State private var isShowingProfile = false
    @State private var isShowingAddWorkLog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if let errorMessage = viewModel.errorMessage {
                        errorState(errorMessage)
                    }
                    IncomeSummaryCard(summaries: viewModel.summariesByCurrency, totalHours: viewModel.totalHours)
                    metricsGrid
                    addHoursButton
                    if !viewModel.isLoading && viewModel.monthlyWorkLogs.isEmpty && viewModel.errorMessage == nil {
                        emptyState
                    }
                    clientsAccess
                    contractsAccess
                    recentActivity
                    accountSection
                    logoutButton
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if viewModel.isLoading && viewModel.monthlyWorkLogs.isEmpty && viewModel.recentWorkLogs.isEmpty {
                    ProgressView()
                }
            }
            .task {
                viewModel.configure(authManager: authManager)
                await viewModel.loadDashboard()
            }
            .refreshable {
                await viewModel.loadDashboard()
            }
            .sheet(isPresented: $isShowingProfile) {
                ProfileView()
            }
            .sheet(isPresented: $isShowingAddWorkLog, onDismiss: {
                Task {
                    await viewModel.loadDashboard()
                }
            }) {
                AddWorkLogView()
                    .environmentObject(authManager)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hola, \(authManager.currentUser?.name ?? "Contractor")")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Aquí tienes tu resumen de \(viewModel.monthTitle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isShowingProfile = true
            } label: {
                UserAvatarView(user: authManager.currentUser, size: 38)
                    .environmentObject(authManager)
            }
            .accessibilityLabel("Perfil")
        }
        .padding(.top, 8)
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 102), spacing: 12)], spacing: 12) {
            MetricCard(
                title: "Horas",
                value: "\(viewModel.totalHours.formattedHours) h",
                systemImage: "clock.fill",
                tint: .blue
            )

            MetricCard(
                title: "Overtime",
                value: "\(viewModel.overtimeHours.formattedHours) h",
                systemImage: "clock.badge.exclamationmark.fill",
                tint: .orange
            )

            MetricCard(
                title: "Registros",
                value: "\(viewModel.workLogCount)",
                systemImage: "list.bullet.rectangle.fill",
                tint: .green
            )

            MetricCard(
                title: "Contratos",
                value: "\(viewModel.workedContractCount)",
                systemImage: "doc.text.fill",
                tint: .indigo
            )
        }
    }

    private var addHoursButton: some View {
        Button {
            isShowingAddWorkLog = true
        } label: {
            Label("Registrar horas", systemImage: "clock.badge.checkmark")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.blue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Abre el formulario para registrar horas trabajadas")
    }

    private var clientsAccess: some View {
        NavigationLink {
            ClientsView()
        } label: {
            AccountActionRow(
                title: "Clientes",
                subtitle: "Gestionar clientes",
                systemImage: "person.2.fill",
                tint: .purple
            )
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var contractsAccess: some View {
        NavigationLink {
            ContractsView()
        } label: {
            AccountActionRow(
                title: "Contratos",
                subtitle: "Gestionar contratos",
                systemImage: "doc.text.fill",
                tint: .indigo
            )
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var recentActivity: some View {
        DashboardSection(title: "Actividad reciente") {
            if viewModel.recentWorkLogs.isEmpty {
                Text("No hay actividad reciente.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.recentWorkLogs) { workLog in
                        NavigationLink {
                            WorkLogDetailView(workLog: workLog, workLogsViewModel: workLogsViewModel)
                        } label: {
                            RecentWorkLogRow(workLog: workLog)
                        }
                        .buttonStyle(.plain)

                        if workLog.id != viewModel.recentWorkLogs.last?.id {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        Text("No registraste horas este mes.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.red)

            Button {
                Task {
                    await viewModel.loadDashboard()
                }
            } label: {
                Label("Reintentar", systemImage: "arrow.clockwise")
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var accountSection: some View {
        DashboardSection(title: "Cuenta") {
            VStack(spacing: 0) {
                Button {
                    isShowingProfile = true
                } label: {
                    AccountActionRow(
                        title: "Perfil",
                        subtitle: "Datos de cuenta",
                        systemImage: "person.text.rectangle",
                        tint: .blue
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 46)

                NavigationLink {
                    ChangePasswordView()
                } label: {
                    AccountActionRow(
                        title: "Seguridad",
                        subtitle: "Cambiar contraseña",
                        systemImage: "lock.rotation",
                        tint: .indigo
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 46)

                NavigationLink {
                    DevicesView()
                } label: {
                    AccountActionRow(
                        title: "Dispositivos",
                        subtitle: "Sesiones vinculadas",
                        systemImage: "iphone.gen3",
                        tint: .teal
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var logoutButton: some View {
        Button(role: .destructive) {
            Task {
                await authManager.logout()
            }
        } label: {
            Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
}

private struct IncomeSummaryCard: View {
    let summaries: [DashboardCurrencySummary]
    let totalHours: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Estimado este mes", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            if summaries.isEmpty {
                Text("Sin ingresos estimados")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            } else if summaries.count == 1, let summary = summaries.first {
                Text(summary.estimatedIncome.formattedCurrency(code: summary.currency))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .accessibilityLabel("Estimado este mes \(summary.estimatedIncome.formattedCurrency(code: summary.currency))")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(summaries) { summary in
                        HStack {
                            Text(summary.currency)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(summary.estimatedIncome.formattedCurrency(code: summary.currency))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
            }

            Text("\(totalHours.formattedHours) h trabajadas")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 8)
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct RecentWorkLogRow: View {
    let workLog: WorkLog

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workLog.isOvertime ? "clock.badge.exclamationmark" : "clock")
                .font(.subheadline)
                .foregroundStyle(workLog.isOvertime ? .orange : .secondary)
                .frame(width: 32, height: 32)
                .background(Color(.tertiarySystemGroupedBackground), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(workLogDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(workLog.hours) h")
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .padding(.vertical, 12)
    }

    private var title: String {
        if let note = workLog.note, !note.isEmpty {
            return "\(workLog.contract.name) · \(workLog.contract.client.name) · \(note)"
        }
        return "\(workLog.contract.name) · \(workLog.contract.client.name)"
    }

    private var workLogDate: String {
        let baseDate: String
        if Calendar.current.isDateInToday(workLog.workDate) {
            baseDate = "Hoy"
        } else if Calendar.current.isDateInYesterday(workLog.workDate) {
            baseDate = "Ayer"
        } else {
            baseDate = workLog.workDate.formatted(.dateTime.day().month(.abbreviated))
        }
        return workLog.isOvertime ? "\(baseDate) · Overtime" : baseDate
    }
}

private struct AccountActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct DashboardSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

private extension Decimal {
    var formattedHours: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "0"
    }

    func formattedCurrency(code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "\(code) 0"
    }
}

#Preview {
    DashboardView()
        .environmentObject(AuthManager())
}
