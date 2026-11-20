// FILE: ProgressRingView.swift
import SwiftUI

struct ProgressRingView: View {
    let progress: Double
    var isFinished: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 5)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    isFinished ? .green : .accentColor,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            if isFinished {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            } else {
                Text("\(Int(progress * 100))")
                    .font(.system(size: 11, weight: .bold))
            }
        }
    }
}
