// FILE: HistoryRowView.swift
import SwiftUI

struct HistoryRowView: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.completed ? "checkmark.circle.fill" : "stop.circle.fill")
                .font(.title2)
                .foregroundStyle(session.completed ? .green : .orange)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.headline)
                Text(timeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(FocusFormat.duration(session.actualDuration))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(session.completed ? "Completed" : "Ended early")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: session.startedAt)) – \(formatter.string(from: session.endedAt))"
    }
}
