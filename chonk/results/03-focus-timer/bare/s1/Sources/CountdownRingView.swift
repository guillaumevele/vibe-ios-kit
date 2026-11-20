// FILE: CountdownRingView.swift
import SwiftUI

struct CountdownRingView: View {
    let progress: Double
    let remaining: TimeInterval
    let phase: FocusTimerViewModel.Phase
    let title: String

    private let ringDiameter: CGFloat = 280
    private let lineWidth: CGFloat = 16

    private var isRunning: Bool { phase == .running }

    var body: some View {
        ZStack {
            ticks
            track
            progressRing
            centerContent
        }
        .frame(width: 340, height: 340)
    }

    private var track: some View {
        Circle()
            .stroke(
                Color.primary.opacity(0.08),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: ringDiameter, height: ringDiameter)
    }

    private var progressRing: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                AngularGradient(
                    colors: [.green, .mint, .teal, .cyan],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: ringDiameter, height: ringDiameter)
            .rotationEffect(.degrees(-90))
            .shadow(color: .green.opacity(isRunning ? 0.45 : 0.15), radius: isRunning ? 24 : 8)
            .animation(.easeInOut(duration: 0.5), value: isRunning)
            .animation(
                (phase == .running || phase == .paused)
                    ? .linear(duration: 0.12)
                    : .smooth(duration: 0.5),
                value: progress
            )
    }

    private var ticks: some View {
        let tickRadius = ringDiameter / 2 + 16
        return ForEach(0..<60) { index in
            let isMajor = index % 5 == 0
            let elapsed = Double(index) / 60 <= 1 - progress
            Rectangle()
                .fill(Color.primary.opacity(elapsed ? 0.4 : 0.12))
                .frame(width: isMajor ? 2.5 : 1.2, height: isMajor ? 12 : 7)
                .offset(y: -tickRadius)
                .rotationEffect(.degrees(Double(index) * 6))
        }
    }

    private var centerContent: some View {
        VStack(spacing: 6) {
            Text(title.isEmpty ? "Focus" : title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal)

            Text(Formatters.mmss(remaining))
                .font(.system(size: 66, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)

            Text(statusLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isRunning ? .green : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: .capsule)
        }
    }

    private var statusLabel: String {
        switch phase {
        case .idle: return "Ready"
        case .running: return "Focusing…"
        case .paused: return "Paused"
        case .finished: return "Done"
        }
    }
}
