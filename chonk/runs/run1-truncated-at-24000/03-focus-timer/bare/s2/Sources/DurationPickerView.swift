// FILE: DurationPickerView.swift
import SwiftUI
import UIKit

/// Preset chips plus a slider for a custom duration (5–90 minutes, 5-minute steps).
struct DurationPickerView: View {
    @Binding var selection: TimeInterval

    private let presets: [TimeInterval] = [15, 25, 30, 45, 60].map { TimeInterval($0) * 60 }

    var body: some View {
        VStack(spacing: 14) {
            Text("Duration")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        selection = preset
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("\(Int(preset / 60))")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 46, height: 38)
                            .foregroundStyle(selection == preset ? .white : .primary)
                            .background(
                                selection == preset ? Theme.accent : Color.secondary.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Slider(
                value: Binding(
                    get: { selection },
                    set: { selection = ($0 / 300).rounded() * 300 }
                ),
                in: 5 * 60...90 * 60,
                step: 5 * 60
            ) {
                Text("Custom duration")
            }
            .tint(Theme.accent)

            Text("\(Int(selection / 60)) minutes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
    }
}
