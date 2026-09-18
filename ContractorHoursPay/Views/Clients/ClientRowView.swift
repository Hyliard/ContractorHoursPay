import SwiftUI

struct ClientRowView: View {
    let client: Client

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: client.active ? "person.crop.square" : "archivebox")
                .font(.headline)
                .foregroundStyle(client.active ? .blue : .secondary)
                .frame(width: 38, height: 38)
                .background((client.active ? Color.blue : Color.secondary).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(client.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Text(client.active ? "Activo" : "Archivado")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.14), in: Capsule())
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, 6)
    }

    private var subtitle: String {
        client.email ?? client.company ?? "Sin contacto"
    }

    private var statusColor: Color {
        client.active ? .green : .secondary
    }
}

#Preview {
    List {
        ClientRowView(
            client: Client(
                id: "1",
                userId: "user-1",
                name: "Mphasis",
                email: "contact@example.com",
                company: "Mphasis",
                active: true,
                createdAt: .now,
                updatedAt: .now
            )
        )
    }
}
