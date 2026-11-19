// FILE: CountdownRingView.swift
import SwiftUI

struct CountdownRingView: View {
    let progress: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.25), lineWidth: Spacing.ringWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: Spacing.ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 0.2), value: progress)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Ring") {
    CountdownRingView(progress: 0.6)
        .frame(width: Spacing.ringSize, height: Spacing.ringSize)
        .padding()
}
