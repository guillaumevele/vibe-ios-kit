// FILE: ProgressTrack.swift
import SwiftUI

struct ProgressTrack: View {
    let progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let clamped = min(1, max(0, progress))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: geometry.size.width * CGFloat(clamped))
                    .animation(reduceMotion ? nil : .default, value: progress)
            }
        }
    }
}
