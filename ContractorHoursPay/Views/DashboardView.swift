import SwiftUI
import UIKit

struct DashboardView: View {
    @EnvironmentObject private var authManager: AuthManager
    @AppStorage(AppPreferenceKey.hideAmounts) private var hideAmounts = false
    @AppStorage(AppPreferenceKey.highlightOvertime) private var highlightOvertime = true
    @AppStorage(AppPreferenceKey.preferredCurrency) private var preferredCurrency = "USD"
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var workLogsViewModel = WorkLogsViewModel()
    @StateObject private var invoicesViewModel = InvoicesViewModel()
    @State private var isShowingProfile = false
    @State private var isShowingAddWorkLog = false
    @State private var isShowingDeveloperTools = false
    @State private var developerTapCount = 0
    @State private var lastDeveloperTapAt: Date?

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
                    nextDueSection
                    quickActions
                    if !viewModel.isLoading && viewModel.monthlyWorkLogs.isEmpty && viewModel.errorMessage == nil {
                        monthlyEmptyState
                    }
                    recentActivity
                    manageSection
                    accountSection
                    logoutButton
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Resumen")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if viewModel.isLoading && viewModel.monthlyWorkLogs.isEmpty && viewModel.recentWorkLogs.isEmpty {
                    loadingState
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
            .sheet(isPresented: $isShowingDeveloperTools) {
                DeveloperToolsView()
                    .environmentObject(authManager)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ContractorHoursPay")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .onTapGesture {
                        handleDeveloperToolsTap()
                    }
                    .accessibilityLabel("ContractorHoursPay")

                Text("Hola, \(authManager.currentUser?.name ?? "Contratista")")
                    .font(.title2)
                    .fontWeight(.bold)
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
        .padding(.top, 6)
    }

    private func handleDeveloperToolsTap() {
        let now = Date()
        if let lastDeveloperTapAt, now.timeIntervalSince(lastDeveloperTapAt) <= 1.2 {
            developerTapCount += 1
        } else {
            developerTapCount = 1
        }

        lastDeveloperTapAt = now

        if developerTapCount >= 5 {
            developerTapCount = 0
            lastDeveloperTapAt = nil
            isShowingDeveloperTools = true
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            MetricCard(
                title: "Generado",
                value: formattedGenerated,
                systemImage: "chart.line.uptrend.xyaxis",
                tint: .blue
            )

            MetricCard(
                title: "Pendiente",
                value: formattedCurrencyGroups(viewModel.pendingSummaries, hideAmounts: hideAmounts, preferredCurrency: preferredCurrency),
                systemImage: "hourglass",
                tint: .orange
            )

            MetricCard(
                title: "Cobrado",
                value: formattedCurrencyGroups(viewModel.paidSummaries, hideAmounts: hideAmounts, preferredCurrency: preferredCurrency),
                systemImage: "checkmark.seal.fill",
                tint: .green
            )

            MetricCard(
                title: "Vencido",
                value: formattedCurrencyGroups(viewModel.overdueSummaries, hideAmounts: hideAmounts, preferredCurrency: preferredCurrency),
                systemImage: "exclamationmark.triangle.fill",
                tint: .red
            )
        }
    }

    private var formattedGenerated: String {
        formattedCurrencyGroups(
            viewModel.summariesByCurrency.map {
                CurrencyAmountSummary(currency: $0.currency, amount: $0.estimatedIncome)
            },
            hideAmounts: hideAmounts,
            preferredCurrency: preferredCurrency
        )
    }

    @ViewBuilder
    private var nextDueSection: some View {
        DashboardSection(title: "Próximo vencimiento") {
            if let invoice = viewModel.nextDueInvoice {
                NavigationLink {
                    InvoiceDetailView(invoice: invoice, invoicesViewModel: invoicesViewModel)
                        .environmentObject(authManager)
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(invoice.client.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                if let contract = invoice.contract {
                                    Text(contract.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            Text(AppPreferences.financialAmount(invoice.outstandingAmount, currency: invoice.currency, hideAmounts: hideAmounts))
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.trailing)
                        }

                        HStack(spacing: 8) {
                            Label(nextDueDateText(for: invoice), systemImage: "calendar")
                                .font(.caption)
                                .foregroundStyle(nextDueTint(for: invoice))

                            Spacer()

                            Text(invoice.effectiveStatus.title)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(nextDueTint(for: invoice).opacity(0.12), in: Capsule())
                                .foregroundStyle(nextDueTint(for: invoice))
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Próximo vencimiento \(invoice.client.name)")
            } else {
                EmptyDashboardState(
                    systemImage: "calendar.badge.checkmark",
                    title: "No tienes vencimientos próximos",
                    subtitle: "Las facturas pendientes aparecerán acá."
                )
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accesos rápidos")
                .font(.headline)

            HStack(spacing: 10) {
                QuickActionButton(
                    title: "Registrar horas",
                    systemImage: "clock.badge.checkmark",
                    tint: .blue
                ) {
                    impactFeedback()
                    isShowingAddWorkLog = true
                }

                NavigationLink {
                    InvoicesView()
                } label: {
                    QuickActionLabel(title: "Facturas", systemImage: "doc.plaintext.fill", tint: .teal)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { impactFeedback() })

                NavigationLink {
                    PaymentsView()
                } label: {
                    QuickActionLabel(title: "Pagos", systemImage: "banknote.fill", tint: .green)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { impactFeedback() })
            }
        }
    }

    private var recentActivity: some View {
        DashboardSection(title: "Actividad reciente") {
            if viewModel.recentWorkLogs.isEmpty {
                EmptyDashboardState(
                    systemImage: "clock",
                    title: "Sin actividad reciente",
                    subtitle: "Cuando registres horas, aparecerán acá."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.recentWorkLogs) { workLog in
                        NavigationLink {
                            WorkLogDetailView(workLog: workLog, workLogsViewModel: workLogsViewModel)
                        } label: {
                            RecentWorkLogRow(workLog: workLog, highlightOvertime: highlightOvertime)
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

    private var monthlyEmptyState: some View {
        EmptyDashboardState(
            systemImage: "tray",
            title: "Aún no hay movimientos este mes",
            subtitle: "Registra horas para empezar a ver tu resumen."
        )
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("No se pudo cargar el resumen.", systemImage: "exclamationmark.triangle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)

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

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Cargando resumen...")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var manageSection: some View {
        DashboardSection(title: "Gestionar") {
            VStack(spacing: 0) {
                NavigationLink {
                    ClientsView()
                } label: {
                    AccountActionRow(title: "Clientes", subtitle: "Gestionar clientes", systemImage: "person.2.fill", tint: .purple)
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 46)

                NavigationLink {
                    ContractsView()
                } label: {
                    AccountActionRow(title: "Contratos", subtitle: "Gestionar contratos", systemImage: "doc.text.fill", tint: .indigo)
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 46)

                NavigationLink {
                    InvoicesView()
                } label: {
                    AccountActionRow(title: "Facturas", subtitle: "Gestionar facturación", systemImage: "doc.plaintext.fill", tint: .teal)
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 46)

                NavigationLink {
                    PaymentsView()
                } label: {
                    AccountActionRow(title: "Pagos", subtitle: "Registrar cobros", systemImage: "banknote.fill", tint: .green)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func nextDueDateText(for invoice: Invoice) -> String {
        guard let dueDate = invoice.dueDate else {
            return "Sin vencimiento"
        }

        if Calendar.current.isDateInToday(dueDate) {
            return "Vence hoy"
        }

        return "Vence \(dueDate.formatted(.dateTime.day().month().year()))"
    }

    private func nextDueTint(for invoice: Invoice) -> Color {
        guard let dueDate = invoice.dueDate else {
            return .secondary
        }

        if invoice.effectiveStatus == .overdue || dueDate.startOfBusinessDay < Date().startOfBusinessDay {
            return .red
        }

        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date().startOfBusinessDay, to: dueDate.startOfBusinessDay).day ?? 99
        return daysUntilDue <= 3 ? .orange : .secondary
    }

    private func impactFeedback() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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

private struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            QuickActionLabel(title: title, systemImage: systemImage, tint: tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct QuickActionLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: Circle())

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, minHeight: 86)
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct EmptyDashboardState: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Color(.tertiarySystemGroupedBackground), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct IncomeSummaryCard: View {
    @AppStorage(AppPreferenceKey.hideAmounts) private var hideAmounts = false
    @AppStorage(AppPreferenceKey.hourFormat) private var hourFormat = "decimal"
    @AppStorage(AppPreferenceKey.preferredCurrency) private var preferredCurrency = "USD"

    let summaries: [DashboardCurrencySummary]
    let totalHours: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Estimado este mes", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    hideAmounts.toggle()
                } label: {
                    Image(systemName: hideAmounts ? "eye.slash" : "eye")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hideAmounts ? "Mostrar montos" : "Ocultar montos")
            }

            if summaries.isEmpty {
                Text("Sin ingresos estimados")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            } else if sortedSummaries.count == 1, let summary = sortedSummaries.first {
                Text(AppPreferences.financialAmount(summary.estimatedIncome, currency: summary.currency, hideAmounts: hideAmounts))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .accessibilityLabel("Estimado este mes \(AppPreferences.financialAmount(summary.estimatedIncome, currency: summary.currency, hideAmounts: hideAmounts))")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sortedSummaries) { summary in
                        HStack {
                            Text(summary.currency)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(AppPreferences.financialAmount(summary.estimatedIncome, currency: summary.currency, hideAmounts: hideAmounts))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
            }

            Text("\(AppPreferences.formattedHours(totalHours, hourFormat: hourFormat)) trabajadas")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 8)
    }

    private var sortedSummaries: [DashboardCurrencySummary] {
        summaries.sorted {
            AppPreferences.currencySortPriority($0.currency, preferredCurrency: preferredCurrency)
                < AppPreferences.currencySortPriority($1.currency, preferredCurrency: preferredCurrency)
        }
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
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct RecentWorkLogRow: View {
    @AppStorage(AppPreferenceKey.hourFormat) private var hourFormat = "decimal"

    let workLog: WorkLog
    let highlightOvertime: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workLog.isOvertime ? "clock.badge.exclamationmark" : "clock")
                .font(.subheadline)
                .foregroundStyle(workLog.isOvertime && highlightOvertime ? .orange : .secondary)
                .frame(width: 32, height: 32)
                .background(overtimeBackground, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(workLogDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if workLog.isOvertime {
                    Text("Horas extra")
                        .font(.caption2.weight(highlightOvertime ? .semibold : .regular))
                        .foregroundStyle(highlightOvertime ? .orange : .secondary)
                }
            }

            Spacer()

            Text(AppPreferences.formattedHours(workLog.hours, hourFormat: hourFormat))
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
        return baseDate
    }

    private var overtimeBackground: Color {
        if workLog.isOvertime && highlightOvertime {
            return Color.orange.opacity(0.14)
        }

        return Color(.tertiarySystemGroupedBackground)
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

#Preview {
    DashboardView()
        .environmentObject(AuthManager())
}
