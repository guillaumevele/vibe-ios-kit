// FILE: ContentView.swift
import SwiftUI

struct ContentView: View {
    @ObservedObject var engine: TimerEngine
    let goToHistory: () -> Void

    private let presets: [TimeInterval] = [15, 25, 45, 60].map { $0 * 60 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 36) {
                    ringView
                    controlsView
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background {
                RadialGradient(
                    colors: [Color.blue.opacity(0.14), Color.clear],
                    center: .top,
                    startRadius: 20,
                    endRadius: 420
                )
                .ignoresSafeArea()
            }
            .navigationTitle("Focus")
            .onAppear { FocusNotifier.requestAuthorization() }
        }
    }

    private var ringView: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !engine.isRunning)) { context in
            let date = context.date
            ZStack {
                CountdownRingView(
                    diameter: 280,
                    progress: engine.progress(at: date),
                    lineWidth: 18,
                    isComplete: engine.state == .finished
                )
                .scaleEffect(engine.state == .finished ? 1.04 : 1.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: engine.state)

                VStack(spacing: 6) {
                    Text(formatClock(engine.remaining(at: date)))
                        .font(.system(size: 62, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(engine.state == .finished ? .green : .primary)

                    Text(engine.stateLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    if engine.state == .finished {
                        Label("Saved to history", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.top, 4)
                    }
                }
            }
            .sensoryFeedback(.success, trigger: engine.state)
        }
    }

    @ViewBuilder
    private var controlsView: some View {
        switch engine.state {
        case .idle, .finished:
            VStack(spacing: 18) {
                presetPicker

                Button {
                    engine.start()
                } label: {
                    Label(engine.state == .finished ? "Start again" : "Start focus", systemImage: "play.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .padding(.horizontal, 6)

                if engine.state == .finished {
                    Button("View history", action: goToHistory)
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                }
            }

        case .running:
            HStack(spacing: 14) {
                controlButton(title: "Pause", systemImage: "pause.fill") { engine.pause() }
                controlButton(title: "Reset", systemImage: "arrow.counterclockwise", role: .destructive) { engine.reset() }
            }

        case .paused:
            HStack(spacing: 14) {
                controlButton(title: "Resume", systemImage: "play.fill", prominent: true) { engine.start() }
                controlButton(title: "Reset", systemImage: "arrow.counterclockwise", role: .destructive) { engine.reset() }
            }
        }
    }

    private var presetPicker: some View {
        HStack(spacing: 10) {
            ForEach(presets, id: \.self) { preset in
                let selected = abs(engine.duration - preset) < 1
                Button {
                    engine.setDuration(preset)
                } label: {
                    Text("\(Int(preset / 60)) min")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .glassEffect(in: .capsule)
                }
                .buttonStyle(.plain)
                .tint(selected ? .accentColor : .primary)
            }
        }
    }

    private func controlButton(
        title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Group {
            Button(role: role, action: action) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .padding(.horizontal, 6)
        }
        .buttonStyle(prominent ? AnyButtonStyle(.glassProminent) : AnyButtonStyle(.glass))
    }
}
