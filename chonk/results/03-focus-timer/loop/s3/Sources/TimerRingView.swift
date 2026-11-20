// FILE: TimerRingView.swift
import SwiftUI

struct TimerRingView<Content: View>: View {
    let progress: Double
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let lineWidth: CGFloat = 16
    private let ringSize: CGFloat = 280

    var body: some View {
        let clamped = max(0, min(1, progress))
        ZStack {
            Group {
                Circle()
                    .stroke(Color.secondary.opacity(0.25), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(AppColor.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .linear(duration: 1), value: clamped)
            }
            .accessibilityHidden(true)
            content()
        }
        .frame(width: ringSize, height: ringSize)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Focus timer")
        .accessibilityValue("\(Int(clamped * 100)) percent remaining")
    }
}
