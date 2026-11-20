// FILE: SessionRowView.swift
import SwiftUI

struct SessionRowView: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: session.wasCompleted ? "checkmark.circle.fill" : "stop.circle.fill")
                .font(.title2)
                .foregroundStyle(session.wasCompleted ? .green : .orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.subheadline.weight(.semibold))
                Text(session.startedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.long(session.actualDuration))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(session.wasCompleted ? "completed" : "ended early")
                    .font(.caption2)
                    .foregroundStyle(session.wasCompleted ? .secondary : .orange)
            }
        }
        .padding(.vertical, 6)
    }
}
