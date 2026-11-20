// FILE: Theme.swift
import SwiftUI

enum Theme {
    static let accent: Color = .indigo
    static let track: Color = Color.secondary.opacity(0.15)
    static let glow: Color = Color.cyan.opacity(0.45)

    static let ringGradient = AngularGradient(
        colors: [.cyan, .blue, .indigo, .purple, .pink, .cyan],
        center: .center
    )
}
