// FILE: CountdownRingView.swift
import SwiftUI

/// The animated countdown ring: a track, minute tick marks, and a
/// gradient progress arc with a soft glow. `progress` goes from 1 (full)
/// down to 0 (empty) and is updated every frame by the TimelineView.
struct CountdownRingView: View {
    var progress: CGFloat
    var lineWidth: CGFloat = 16

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                tickMarks(side: side)

                Circle()
                    .stroke(Theme.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                Circle()
                    .trim(from: 0, to: progress > 0 ? max(progress, 0.002) : 0)
                    .stroke(Theme.ringGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Theme.glow, radius: 14)
            }
            .frame(width: side, height: side)
        }
    }

    private func tickMarks(side: CGFloat) -> some View {
        ForEach(0..<60) { index in
            let isMajor = index % 5 == 0
            Rectangle()
                .fill(Color.secondary.opacity(isMajor ? 0.45 : 0.18))
                .frame(width: isMajor ? 2 : 1, height: isMajor ? 10 : 5)
                .offset(y: -(side / 2) + lineWidth + 8)
                .rotationEffect(.degrees(Double(index) * 6))
        }
    }
}
