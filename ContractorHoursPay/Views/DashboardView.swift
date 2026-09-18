import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var isShowingProfile = false
    @State private var isShowingAddWorkLog = false

    private let summary = ContractorDashboardMock.summary
    private let upcomingPayment = ContractorDashboardMock.upcomingPayment
    private let recentWorkLogs = ContractorDashboardMock.recentWorkLogs

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    IncomeSummaryCard(summary: summary)
                    metricsGrid
                    UpcomingPaymentCard(payment: upcomingPayment)
                    addHoursButton
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
            .sheet(isPresented: $isShowingProfile) {
                ProfileView()
            }
            .sheet(isPresented: $isShowingAddWorkLog) {
                AddWorkLogView()
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

                Text("Aquí tienes tu resumen de septiembre")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isShowingProfile = true
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.blue)
                    .accessibilityLabel("Perfil")
            }
        }
        .padding(.top, 8)
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 102), spacing: 12)], spacing: 12) {
            MetricCard(
                title: "Pendiente",
                value: summary.pendingAmount.formattedCurrency(code: summary.currency),
                systemImage: "hourglass.circle.fill",
                tint: .orange
            )

            MetricCard(
                title: "Cobrado",
                value: summary.paidAmount.formattedCurrency(code: summary.currency),
                systemImage: "checkmark.circle.fill",
                tint: .green
            )

            MetricCard(
                title: "Horas",
                value: "\(summary.hoursWorked.formattedHours) h",
                systemImage: "clock.fill",
                tint: .blue
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
            VStack(spacing: 0) {
                ForEach(recentWorkLogs.prefix(4)) { workLog in
                    RecentWorkLogRow(workLog: workLog)

                    if workLog.id != recentWorkLogs.prefix(4).last?.id {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
        }
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
    let summary: ContractorSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Estimado este mes", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Text(summary.estimatedIncome.formattedCurrency(code: summary.currency))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .accessibilityLabel("Estimado este mes \(summary.estimatedIncome.formattedCurrency(code: summary.currency))")

            HStack(spacing: 12) {
                Text("\(summary.hoursWorked.formattedHours) h trabajadas")
                Text("•")
                    .foregroundStyle(.tertiary)
                Text("\(summary.hourlyRate.formattedCurrency(code: summary.currency))/h")
            }
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

private struct UpcomingPaymentCard: View {
    let payment: UpcomingPayment

    var body: some View {
        DashboardSection(title: "Próximo pago") {
            HStack(spacing: 14) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 42, height: 42)
                    .background(Color.blue.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(payment.client.name)
                        .font(.headline)

                    Text(payment.amount.formattedCurrency(code: payment.currency))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(payment.date.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(payment.status)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.14), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

private struct RecentWorkLogRow: View {
    let workLog: WorkLog

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

            Text(workLog.amount.formattedCurrency(code: workLog.currency))
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .padding(.vertical, 12)
    }

    private var title: String {
        if let note = workLog.note, !note.isEmpty {
            return "\(workLog.hours.formattedHours) h \(note) · \(workLog.client.name)"
        }
        return "\(workLog.hours.formattedHours) h · \(workLog.client.name)"
    }

    private var workLogDate: String {
        if Calendar.current.isDateInToday(workLog.date) {
            return "Hoy"
        }
        if Calendar.current.isDateInYesterday(workLog.date) {
            return "Ayer"
        }
        return workLog.date.formatted(.dateTime.day().month(.abbreviated))
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
        NSDecimalNumber(decimal: self)
            .doubleValue
            .formatted(.number.precision(.fractionLength(0...1)))
    }

    func formattedCurrency(code: String) -> String {
        NSDecimalNumber(decimal: self)
            .doubleValue
            .formatted(.currency(code: code))
    }
}

#Preview {
    DashboardView()
        .environmentObject(AuthManager())
}
