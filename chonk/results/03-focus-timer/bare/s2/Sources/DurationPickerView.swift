// FILE: DurationPickerView.swift
import SwiftUI
import Observation

struct DurationPickerView: View {
    @Environment(FocusTimerViewModel.self) private var timer

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(timer.presets, id: \.self) { preset in
                    let selected = timer.selectedDuration == preset
                    Button {
                        timer.selectDuration(preset)
                    } label: {
                        Text("\(Int(preset / 60)) min")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)
                    .background(selected ? Color.accentColor : Color.secondary.opacity(0.14))
                    .foregroundStyle(selected ? .white : .primary)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
