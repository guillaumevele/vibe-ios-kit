// FILE: ProgressHeaderView.swift
import SwiftUI

/// Progress summary shown at the top of the list.
struct ProgressHeaderView: View {
    let done: Int
    let total: Int

    private var isComplete: Bool { total > 0 && done == total }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    isComplete ? "All done!" : "Shopping progress",
                    systemImage: isComplete ? "checkmark.seal.fill" : "cart.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isComplete ? .green : .primary)
                Spacer()
                Text("\(done) of \(total)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(done), total: Double(total))
                .tint(isComplete ? .green : .accentColor)
        }
        .padding(.vertical, 6)
    }
}
