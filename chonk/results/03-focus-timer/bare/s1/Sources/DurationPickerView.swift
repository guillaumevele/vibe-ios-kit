// FILE: DurationPickerView.swift
import SwiftUI

struct DurationPickerView: View {
    @Binding var selected: TimeInterval
    let onSelect: (TimeInterval) -> Void
    @Namespace private var namespace

    private let presets: [TimeInterval] = [5, 15, 25, 45, 60].map { $0 * 60 }

    var body: some View {
        VStack(spacing: 10) {
            Text("Session length")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            GlassEffectContainer(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(presets, id: \.self) { preset in
                            Button {
                                selected = preset
                                onSelect(preset)
                            } label: {
                                VStack(spacing: 1) {
                                    Text("\(Int(preset / 60))")
                                        .font(.headline)
                                    Text("min")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 58, height: 58)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(
                                .regular
                                    .tint(selected == preset ? .accent : .clear)
                                    .interactive(),
                                in: .capsule
                            )
                            .glassEffectID(preset, in: namespace)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
}
