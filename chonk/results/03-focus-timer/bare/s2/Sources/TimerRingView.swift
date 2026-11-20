// FILE: TimerRingView.swift
import SwiftUI

struct TimerRingView: View {
    let progress: Double
    let timeText: String
    let subtitle: String
    let phase: TimerPhase
    var accent: Color = .accentColor

    private let lineWidth: CGFloat = 16
    private let tickCount = 60

    var body: some View {
        ZStack {
            tickRing

            // Track
            Circle()
                .stroke(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            // Animated countdown arc (shrinks as time elapses)
            Circle()
                .trim(from: 0, to: progress > 0 ? CGFloat(progress) : 0)
                .stroke(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: accent.opacity(0.4), radius: 16, y: 6)
                .animation(.linear(duration: 0.12), value: progress)

            // Center content
            VStack(spacing: 8) {
                Text(timeText)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(phase == .finished ? .secondary : .primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if phase == .finished {
                    Label("Saved to history", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(width: 320, height: 320)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: phase)
    }

    private var tickRing: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - lineWidth - 8
            let elapsed = 1 - min(1, max(0, progress))

            for i in 0..<tickCount {
                let fraction = Double(i) / Double(tickCount)
                let radians = (fraction * 360 - 90) * .pi / 180
                let cosR = CGFloat(cos(radians))
                let sinR = CGFloat(sin(radians))
                let isElapsed = fraction <= elapsed
                let innerRadius = radius
                let outerRadius = radius + (isElapsed ? 7 : 5)

                var path = Path()
                path.move(to: CGPoint(x: center.x + innerRadius * cosR, y: center.y + innerRadius * sinR))
                path.addLine(to: CGPoint(x: center.x + outerRadius * cosR, y: center.y + outerRadius * sinR))

                context.stroke(
                    path,
                    with: .color(isElapsed ? accent.opacity(0.9) : Color.primary.opacity(0.15)),
                    lineWidth: isElapsed ? 2.5 : 1.5
                )
            }
        }
    }
}
