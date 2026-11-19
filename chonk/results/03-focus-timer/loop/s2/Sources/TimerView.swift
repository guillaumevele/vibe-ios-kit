// FILE: TimerView.swift
import SwiftUI

struct TimerView: View {
    @Bindable var model: TimerModel
    @State private var pendingReset = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.large) {
                ringSection
                controlsSection
                if let notice = model.notice {
                    Label(notice, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.leading)
                        .accessibilityElement(children: .combine)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Focus Timer")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.history) {
                    Label("History", systemImage: "clock")
                }
            }
        }
        .sensoryFeedback(.success, trigger: model.completedCount)
        .alert("Reset the timer?", isPresented: $pendingReset) {
            Button("Reset", role: .destructive) { model.reset() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The current progress will be lost.")
        }
    }

    private var ringSection: some View {
        ZStack {
            CountdownRing(progress: model.progress)
                .frame(width: 280, height: 280)
            VStack(spacing: Spacing.small) {
                Text(phaseTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                timeText
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Countdown")
        .accessibilityValue("\(model.remainingDescription) remaining")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var phaseTitle: String {
        switch model.phase {
        case .idle: return "Ready"
        case .running: return "Focusing"
        case .paused: return "Paused"
        case .finished: return "Session complete"
        }
    }

    private var timeText: some View {
        Group {
            if model.phase == .running, let endDate = model.endDate {
                Text(timerInterval: Date.now...endDate, countsDown: true)
            } else {
                Text(clockString(model.remaining))
            }
        }
    }

    private func clockString(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var controlsSection: some View {
        VStack(spacing: Spacing.medium) {
            switch model.phase {
            case .idle:
                durationPicker
                Button {
                    model.start()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minHeight: 44)
            case .running:
                HStack(spacing: Spacing.medium) {
                    Button {
                        model.pause()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(minHeight: 44)
                    resetButton
                }
            case .paused:
                HStack(spacing: Spacing.medium) {
                    Button {
                        model.resume()
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(minHeight: 44)
                    resetButton
                }
            case .finished:
                Button {
                    model.reset()
                } label: {
                    Label("Done", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minHeight: 44)
            }
        }
    }

    private var resetButton: some View {
        Button {
            pendingReset = true
        } label: {
            Label("Reset", systemImage: "arrow.counterclockwise")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(minHeight: 44)
    }

    private var durationPicker: some View {
        Picker("Session length", selection: $model.selectedMinutes) {
            ForEach(DurationOption.all) { option in
                Text(option.label).tag(option.minutes)
            }
        }
        .pickerStyle(.segmented)
        .sensoryFeedback(.selection, trigger: model.selectedMinutes)
    }
}

struct CountdownRing: View {
    let progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let lineWidth: CGFloat = 16

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: lineWidth))
            Circle()
                .trim(from: 0, to: CGFloat(min(1, max(0, progress))))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
        }
    }
}

#Preview {
    NavigationStack {
        TimerView(model: TimerModel(store: FileSessionStore.makePreview()))
    }
}
