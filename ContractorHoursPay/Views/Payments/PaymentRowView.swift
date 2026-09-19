import SwiftUI

struct PaymentRowView: View {
    let payment: Payment

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: payment.active ? "banknote" : "archivebox")
                .font(.headline)
                .foregroundStyle(payment.active ? .green : .secondary)
                .frame(width: 38, height: 38)
                .background((payment.active ? Color.green : Color.secondary).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text((decimalValue(payment.amount) ?? 0).formattedCurrency(code: payment.currency))
                    .font(.headline)

                Text(payment.client.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(payment.paidAt.formatted(.dateTime.day().month().year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(payment.active ? payment.invoice.effectiveStatus.title : "Archived")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((payment.active ? Color.green : Color.secondary).opacity(0.14), in: Capsule())
                .foregroundStyle(payment.active ? .green : .secondary)
        }
        .padding(.vertical, 6)
    }
}
