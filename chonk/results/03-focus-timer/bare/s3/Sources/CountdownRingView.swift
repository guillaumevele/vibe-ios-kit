// FILE: CountdownRingView.swift
import SwiftUI

struct CountdownRingView: View {
    let diameter: CGFloat
    let progress: Double          // 0...1 of the session remaining
    let lineWidth: CGFloat
    var isComplete: Bool = false

    private var centerlineRadius: CGFloat { diameter / 2 }
    private var tickRadius: CGFloat { centerlineRadius + lineWidth / 2 + 6 }
    private var outerSize: CGFloat { diameter + lineWidth + 16 }
    private var shownProgress: CGFloat { isComplete ? 1 : CGFloat(min(1, max(0, progress))) }

    private var colors: [Color] {
        isComplete
            ? [Color.green, Color.mint, Color.green]
            : [Color.cyan, Color.blue, Color.indigo, Color.purple]
    }

    var body: some View {
        ZStack {
            // Minute tick marks around the ring
            ForEach(0..<60) { index in
                Rectangle()
                    .fill(Color.primary.opacity(index % 5 == 0 ? 0.22 : 0.08))
                    .frame(width: index % 5 == 0 ? 2 : 1, height: index % 5 == 0 ? 10 : 6)
                    .offset(y: -tickRadius)
                    .rotationEffect(.degrees(Double(index) * 6))
            }

            ZStack {
                // Track
                Circle()
                    .stroke(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                // Depleting progress arc
                Circle()
                    .trim(from: 0, to: shownProgress)
                    .stroke(
                        AngularGradient(colors: colors, center: .center, startAngle: .degrees(0), endAngle: .degrees(360)),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: (isComplete ? Color.green : Color.blue).opacity(0.5), radius: 16, y: 6)
            }
            .frame(width: diameter, height: diameter)
        }
        .frame(width: outerSize, height: outerSize)
    }
}
