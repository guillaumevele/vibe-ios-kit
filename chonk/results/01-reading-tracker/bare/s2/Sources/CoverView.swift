// FILE: CoverView.swift
import SwiftUI

struct CoverView: View {
    let book: Book
    var width: CGFloat = 48

    private var height: CGFloat { width * 1.45 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.09, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [book.coverColor, book.coverColor.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            VStack(spacing: width * 0.06) {
                Text(book.initials)
                    .font(.system(size: width * 0.3, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(book.title)
                    .font(.system(size: max(width * 0.085, 8), weight: .semibold))
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, width * 0.08)
            }
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.18), radius: width * 0.06, y: width * 0.03)
    }
}
