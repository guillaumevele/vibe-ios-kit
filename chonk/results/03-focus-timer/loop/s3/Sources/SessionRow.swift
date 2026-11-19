// FILE: SessionRow.swift
import SwiftUI

struct SessionRow: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: session.completed ? "checkmark.circle.fill" : "stop.circle")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(session.completed ? AppColor.accent : Color.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.completed ? "Completed session" : "Ended early")
                    .font(.headline)
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(session.duration / 60)) min")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Spacing.small)
        .accessibilityElement(children: .combine)
    }
}
