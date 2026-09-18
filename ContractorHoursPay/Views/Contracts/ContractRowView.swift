import SwiftUI

struct ContractRowView: View {
    let contract: Contract

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: contract.active ? "doc.text.fill" : "archivebox")
                .font(.headline)
                .foregroundStyle(contract.active ? .blue : .secondary)
                .frame(width: 38, height: 38)
                .background((contract.active ? Color.blue : Color.secondary).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(contract.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(contract.client.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(contract.hourlyRate) \(contract.currency)/h")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(contract.active ? "Activo" : "Archivado")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.vertical, 6)
    }

    private var statusColor: Color {
        contract.active ? .green : .secondary
    }
}
