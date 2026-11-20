// FILE: SessionDetailView.swift
import SwiftUI
import Foundation

struct SessionDetailView: View {
    let session: FocusSession

    var body: some View {
        List {
            Section {
                Label(
                    session.completed ? "Completed" : "Ended early",
                    systemImage: session.completed ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .foregroundStyle(session.completed ? .green : .secondary)
            }
            Section("Session") {
                LabeledContent("Planned") {
                    Text(Duration.seconds(session.plannedDuration).formatted(.units(allowed: [.minute, .second])))
                }
                LabeledContent("Actual") {
                    Text(Duration.seconds(session.actualDuration).formatted(.units(allowed: [.minute, .second])))
                }
                LabeledContent("Started") {
                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                }
                LabeledContent("Ended") {
                    Text(session.endedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        .navigationTitle("Session")
    }
}
