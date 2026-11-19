// FILE: TimerView.swift
import SwiftUI

struct TimerView: View {
    @Bindable var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showEndConfirmation = false

    private let durations = [5, 15, 25, 50]

    var body: some View {
        VStack(spacing: Spacing.large) {
            Spacer()
            TimerRingView(progress: model.progress) {
                countdownText
            }
            statusText
            controls
            Spacer()
        }
        .padding()
        .navigationTitle("Focus")
        .sensoryFeedback(.selection, trigger: model.phase)
        .task {
            model.handleAppear()
        }
        .onChange(of: scenePhase) { _, newPhase in
            model.handleScenePhase(newPhase)
        }
        .onDisappear {
            model.handleDisappear()
        }
        .alert("End this session?", isPresented: $showEndConfirmation) {
            Button("End session", role: .destructive) {
                model.endSession(completed: false)
            }
            Button("Keep going", role: .cancel) { }
        } message: {
            Text("The session will be saved as ended early.")
        }
    }

    private var countdownText: some View {
        Group {
            switch model.phase {
            case .idle:
                Text("\(model.durationMinutes) min")
            case .running:
                Text(
                    timerInterval: DateInterval(start: Date(), end: model.endDate),
                    countsDown: true
                )
                .monospacedDigit()
            case .paused:
                Text(
                    timerInterval: DateInterval(
                        start: Date(),
                        end: Date().addingTimeInterval(model.remaining)
                    ),
                    pauseTime: Date(),
                    countsDown: true
                )
                .monospacedDigit()
            case .finished(let completed):
                Label(
                    completed ? "Complete" : "Ended early",
                    systemImage: completed ? "checkmark.circle.fill" : "exclamationmark.circle"
                )
            }
        }
        .font(.largeTitle)
        .fontWeight(.bold)
        .minimumScaleFactor(0.5)
    }

    private var statusText: some View {
        Group {
            switch model.phase {
            case .idle:
                Text("Choose a duration, then start")
            case .running:
                Label("Focusing", systemImage: "circle.fill")
                    .foregroundStyle(AppColor.accent)
            case .paused:
                Label("Paused", systemImage: "pause.circle")
            case .finished(let completed):
                Text(completed ? "Session saved to history" : "Saved to history as ended early")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private var controls: some View {
        Group {
            switch model.phase {
            case .idle:
                VStack(spacing: Spacing.medium) {
                    Picker("Duration", selection: $model.durationMinutes) {
                        ForEach(durations, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: model.durationMinutes) { _, newValue in
                        model.applyDuration(newValue)
                    }
                    Button {
                        model.start()
                    } label: {
                        Label("Start focus session", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            case .running:
                buttonRow {
                    Button {
                        model.pause()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .buttonStyle(.bordered)
                    Button(role: .destructive) {
                        showEndConfirmation = true
                    } label: {
                        Label("End", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                }
            case .paused:
                buttonRow {
                    Button {
                        model.resume()
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    Button(role: .destructive) {
                        showEndConfirmation = true
                    } label: {
                        Label("End", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                }
            case .finished:
                buttonRow {
                    Button {
                        model.start()
                    } label: {
                        Label("Start again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        model.resetToIdle()
                    } label: {
                        Label("Done", systemImage: "checkmark")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(minHeight: 44)
    }

    private func buttonRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: Spacing.medium) {
            content()
        }
        .controlSize(.large)
    }
}
