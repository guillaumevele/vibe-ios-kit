// FILE: BookCoverView.swift
import SwiftUI

/// A small generated "cover" with the book's initials on a deterministic gradient.
struct BookCoverView: View {
    let title: String
    let author: String

    private static let palette: [Color] = [
        .blue, .indigo, .purple, .teal, .mint, .orange, .pink, .red, .brown, .cyan
    ]

    private var initials: String {
        let words = title.split(separator: " ").filter { !$0.isEmpty }
        let letters = words.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    private var baseColor: Color {
        let hash = title.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return Self.palette[abs(hash) % Self.palette.count]
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [baseColor, baseColor.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(initials)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 48, height: 66)
        .shadow(radius: 2, y: 1)
    }
}
