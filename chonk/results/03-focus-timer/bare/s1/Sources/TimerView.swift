// FILE: TimerView.swift
import SwiftUI
import SwiftData

struct TimerView: View {
    @State private var vm = FocusTimerViewModel()
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isEditingTitle: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    if vm.phase == .idle {
                        TextField("Session name", text: $vm.title)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(maxWidth: 280)
                            .glassEffect(in: .rect(cornerRadius: 16))
                            .focused($isEditingTitle)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    CountdownRingView(
                        progress: vm.progress,
                        remaining: vm.remaining,
                        phase: vm.phase,
                        title: vm.title
                    )

                    if vm.phase == .idle {
                        DurationPickerView(selected: $vm.plannedDuration) { duration in
                            vm.selectDuration(duration)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    controls
                        .padding(.bottom, 24)
                }
                .padding(.top, 8)
                .animation(.smooth(duration: 0.35), value: vm.phase)
            }
            .navigationTitle("Focus")
            .onAppear {
                vm.attach(onSessionEnded: recordSession)
                vm.resync()
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: vm.phase)
            .sensoryFeedback(.success, trigger: vm.phase == .finished)
            .overlay {
                if vm.phase == .finished {
                    CelebrationView(duration: vm.plannedDuration) {
                        vm.dismissFinished()
                    }
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            switch vm.phase {
            case .idle:
                Button {
                    vm.start()
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

            case .running:
                Button {
                    vm.pause()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .frame(minWidth: 110)
                }
                .buttonStyle(.glass)
                .controlSize(.large)

                Button(role: .destructive) {
                    vm.endEarly()
                } label: {
                    Label("End", systemImage: "stop.fill")
                        .frame(minWidth: 90)
                }
                .buttonStyle(.glass)
                .controlSize(.large)

            case .paused:
                Button {
                    vm.start()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .frame(minWidth: 110)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

                Button(role: .destructive) {
                    vm.endEarly()
                } label: {
                    Label("End", systemImage: "stop.fill")
                        .frame(minWidth: 90)
                }
                .buttonStyle(.glass)
                .controlSize(.large)

            case .finished:
                EmptyView()
            }
        }
    }

    private func recordSession(actual: TimeInterval, completed: Bool) {
        let trimmed = vm.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = FocusSession(
            title: trimmed.isEmpty ? "Focus" : trimmed,
            plannedDuration: vm.plannedDuration,
            actualDuration: actual,
            startedAt: Date().addingTimeInterval(-actual),
            endedAt: .now,
            wasCompleted: completed
        )
        modelContext.insert(session)
        try? modelContext.save()
    }
}
