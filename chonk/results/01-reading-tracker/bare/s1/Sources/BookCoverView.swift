// FILE: BookCoverView.swift
import SwiftUI

/// A small generated "cover" showing the book's initials on a colour
/// derived from the title, so no image assets are needed.
struct BookCoverView: View {
    let book: Book

    private var initials: String {
        let words = book.title.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first.map(String.init) }
        let result = letters.joined().uppercased()
        return result.isEmpty ? "?" : result
    }

    private var hue: Double {
        let hash = book.title.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        return Double(hash.magnitude % 360) / 360.0
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: hue, saturation: 0.55, brightness: 0.80),
                            Color(hue: hue, saturation: 0.65, brightness: 0.50)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(initials)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 54, height: 76)
        .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
    }
}
