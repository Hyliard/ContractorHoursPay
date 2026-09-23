import SwiftUI

struct WorkLogRowView: View {
    @AppStorage(AppPreferenceKey.highlightOvertime) private var highlightOvertime = true

    let workLog: WorkLog

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workLog.isOvertime ? "clock.badge.exclamationmark" : "clock")
                .font(.headline)
                .foregroundStyle(iconColor)
                .frame(width: 38, height: 38)
                .background(iconColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(workLog.workDate.formatted(.dateTime.day().month().year()))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(workLog.contract.name) · \(workLog.contract.client.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let note = workLog.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(workLog.hours) h")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(statusText)
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

    private var statusText: String {
        workLog.active ? (workLog.isOvertime ? "Horas extra" : "Activo") : "Archivado"
    }

    private var statusColor: Color {
        if !workLog.active {
            return .secondary
        }
        return workLog.isOvertime && highlightOvertime ? .orange : .green
    }

    private var iconColor: Color {
        workLog.isOvertime && highlightOvertime ? .orange : .blue
    }
}
