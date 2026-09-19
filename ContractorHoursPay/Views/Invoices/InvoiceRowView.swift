import SwiftUI

struct InvoiceRowView: View {
    let invoice: Invoice

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(invoice.client.name)
                        .font(.headline)

                    if let contract = invoice.contract {
                        Text(contract.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(periodText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                statusBadge
            }

            HStack {
                moneyColumn("Subtotal", invoice.subtotal)
                Spacer()
                moneyColumn("Paid", invoice.paidAmount)
                Spacer()
                moneyColumn("Outstanding", invoice.outstandingAmount)
            }

            if let dueDate = invoice.dueDate {
                Text("Due \(dueDate.formatted(.dateTime.day().month().year()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var periodText: String {
        "\(invoice.periodFrom.formatted(.dateTime.day().month().year())) - \(invoice.periodTo.formatted(.dateTime.day().month().year()))"
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.14), in: Capsule())
            .foregroundStyle(statusColor)
    }

    private var statusText: String {
        if !invoice.active {
            return "Archived"
        }
        return invoice.effectiveStatus.title
    }

    private var statusColor: Color {
        if !invoice.active {
            return .secondary
        }

        switch invoice.effectiveStatus {
        case .draft:
            return .secondary
        case .pending:
            return .orange
        case .paid:
            return .green
        case .cancelled:
            return .secondary
        case .overdue:
            return .red
        }
    }

    private func moneyColumn(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text((decimalValue(value) ?? 0).formattedCurrency(code: invoice.currency))
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}
