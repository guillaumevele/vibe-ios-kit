// FILE: CoverView.swift
import SwiftUI

struct CoverView: View {
    let title: String
    let author: String
    var size: CGFloat = 64

    private var initials: String {
        let words = title.split(separator: " ").map(String.init)
        let first = words.first?.first.map(String.init) ?? "?"
        let second = words.count > 1 ? String(words[1].first ?? " ") : ""
        return (first + second).uppercased()
    }

    private var hue: Double {
        let hash = title.utf8.reduce(0) { ($0 &+ Int($1)) % 360 }
        return Double(hash) / 360.0
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hue: hue, saturation: 0.45, brightness: 0.85))
            Text(initials)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size * 1.4)
    }
}
