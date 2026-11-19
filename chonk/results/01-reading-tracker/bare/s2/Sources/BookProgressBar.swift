// FILE: BookProgressBar.swift
import SwiftUI

struct BookProgressBar: View {
    let progress: Double
    var color: Color = .accentColor
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                Capsule()
                    .fill(color)
                    .frame(width: max(geo.size.width * CGFloat(min(max(progress, 0), 1)), height))
            }
        }
        .frame(height: height)
    }
}
