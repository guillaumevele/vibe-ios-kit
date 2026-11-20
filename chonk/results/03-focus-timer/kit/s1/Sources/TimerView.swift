// FILE: TimerView.swift
import SwiftUI
import Foundation

struct TimerView: View {
    @Bindable var model: TimerModel
    @Binding var path: NavigationPath

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.large) {
            Group {
                if model.phase == .idle {
                    durationPicker
                }
            }
            .animation(reduceMotion ? nil : .default, value: model.phase)

            Spacer()

            ring

            Spacer()

            controls

            if let notice = model.notice {
                Label(notice, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .navigationTitle("Focus")
        .sensoryFeedback(.selection, trigger: model.phase)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    path.append(Route.history)
                } label: {
                    Label("History", systemImage: "clock")
                }
            }
        }
        .onChange(of: model.selectedMinutes) { _, _ in
            model.syncDuration()
        }
    }

    private var durationPicker: some View {
        Picker("Session length", selection: $model.selectedMinutes) {
            ForEach([5, 10, 15, 25, 30, 45, 60], id: \.self) { minutes in
                Text(Duration.seconds(Double(minutes) * 60).formatted(.units(allowed: [.minute])))
                    .tag(minutes)
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 110)
        .sensoryFeedback(.selection, trigger: model.selectedMinutes)
    }

    private var ring: some View {
        ZStack {
            CountdownRingView(progress: model.progress)
                .frame(width: Spacing.ringSize, height: Spacing.ringSize)
            VStack(spacing: Spacing.xSmall) {
                timeText
                    .font(.system(.largeTitle, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.4)
                phaseLabel
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Focus timer"))
        .accessibilityValue(Text(Duration.seconds(model.remaining).formatted(.units(allowed: [.minute, .second]))))
    }

    private var timeText: some View {
        switch model.phase {
        case .idle:
            Text(timerInterval: Date.now...(Date.now + model.totalDuration), pauseTime: Date.now, countsDown: true, showsHours: false)
        case .running:
            Group {
                if let endDate = model.endDate {
                    Text(timerInterval: Date.now...endDate, countsDown: true, showsHours: false)
                }
            }
        case .paused:
            Text(timerInterval: Date.now...(Date.now + model.remaining), pauseTime: Date.now, countsDown: true, showsHours: false)
        case .finished:
            Text(timerInterval: Date.now...Date.now, countsDown: true, showsHours: false)
        }
    }

    private var phaseLabel: Text {
        switch model.phase {
        case .idle: Text("Ready")
        case .running: Text("Focusing")
        case .paused: Text("Paused")
        case .finished: Text("Complete")
        }
    }

    private var controls: some View {
        HStack(spacing: Spacing.medium) {
            switch model.phase {
            case .idle:
                Button("Start focus session", systemImage: "play.fill") {
                    model.start()
                }
                .buttonStyle(.borderedProminent)
            case .running:
                Button("Pause", systemImage: "pause.fill") {
                    model.pause()
                }
                .buttonStyle(.bordered)
                Button("End early", systemImage: "stop.fill") {
                    model.endEarly()
                }
                .buttonStyle(.bordered)
            case .paused:
                Button("Resume", systemImage: "play.fill") {
                    model.resume()
                }
                .buttonStyle(.borderedProminent)
                Button("Reset", systemImage: "arrow.counterclockwise") {
                    model.reset()
                }
                .buttonStyle(.bordered)
            case .finished:
                Button("Start again", systemImage: "arrow.clockwise") {
                    model.reset()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .font(.headline)
        .controlSize(.large)
    }
}

private struct TimerPreviewRoot: View {
    @State private var model = TimerModel(store: MemorySessionStore())
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            TimerView(model: model, path: $path)
        }
    }
}

#Preview("Timer") {
    TimerPreviewRoot()
}
