// FILE: ContentView.swift
import SwiftUI
import Observation

struct ContentView: View {
    @Environment(SessionStore.self) private var store
    @Environment(FocusTimerViewModel.self) private var timer
    @Environment(\.scenePhase) private var scenePhase
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    statsRow

                    TimerRingView(
                        progress: timer.progress,
                        timeText: timer.timeText,
                        subtitle: timer.subtitle,
                        phase: timer.phase
                    )

                    if !timer.isActive {
                        VStack(spacing: 16) {
                            TextField("What are you focusing on?", text: $timer.title)
                                .textFieldStyle(.roundedBorder)
                                .font(.subheadline)

                            DurationPickerView()
                        }
                    }

                    controls
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .navigationTitle("Focus")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                NavigationStack {
                    SessionHistoryView()
                }
            }
            .onAppear {
                timer.requestNotificationAuthorization()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    timer.syncWithClock()
                }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(title: "Today", value: FocusFormat.duration(store.totalToday))
            StatCard(title: "This week", value: FocusFormat.duration(store.totalThisWeek))
            StatCard(title: "Sessions", value: "\(store.sessions.count)")
        }
    }

    private var controls: some View {
        GlassEffectContainer(spacing: 20) {
            HStack(spacing: 20) {
                switch timer.phase {
                case .idle, .finished:
                    Button { timer.start() } label: {
                        Label("Start focus", systemImage: "play.fill")
                    }
                    .glassEffect(.regular.tint(.green).interactive())

                case .running:
                    Button { timer.pause() } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .glassEffect(.regular.tint(.orange).interactive())

                    Button { timer.endEarly() } label: {
                        Label("End", systemImage: "stop.fill")
                    }
                    .glassEffect(.regular.tint(.red).interactive())

                case .paused:
                    Button { timer.resume() } label: {
                        Label("Resume", systemImage: "play.fill")
                    }
                    .glassEffect(.regular.tint(.green).interactive())

                    Button { timer.reset() } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .glassEffect(.regular.tint(.gray).interactive())
                }
            }
            .font(.headline)
            .buttonStyle(.plain)
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassEffect(.regular)
    }
}
