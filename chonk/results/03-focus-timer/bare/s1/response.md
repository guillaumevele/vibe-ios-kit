Here's a complete iOS 26 focus timer app built entirely with Apple frameworks — SwiftUI (with Liquid Glass effects), Observation, SwiftData for persistent history, and Combine-free timer logic driven by `Date` so it survives backgrounding.

```swift
// FILE: FocusTimerApp.swift
import SwiftUI
import SwiftData

@main
struct FocusTimerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: FocusSession.self)
    }
}
```

```swift
// FILE: FocusSession.swift
import Foundation
import SwiftData

@Model
final class FocusSession {
    var title: String
    var plannedDuration: TimeInterval
    var actualDuration: TimeInterval
    var startedAt: Date
    var endedAt: Date
    var wasCompleted: Bool

    init(
        title: String,
        plannedDuration: TimeInterval,
        actualDuration: TimeInterval,
        startedAt: Date,
        endedAt: Date,
        wasCompleted: Bool
    ) {
        self.title = title
        self.plannedDuration = plannedDuration
        self.actualDuration = actualDuration
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.wasCompleted = wasCompleted
    }
}
```

```swift
// FILE: Formatters.swift
import Foundation

enum Formatters {
    /// "MM:SS" countdown format, e.g. 25:00 -> 24:59 ...
    static func mmss(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// Human readable duration for history, e.g. "25 min", "1 hr 5 min"
    static func long(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours) hr \(minutes) min" : "\(hours) hr"
        }
        if minutes > 0 {
            return seconds >= 30 ? "\(minutes + 1) min" : "\(minutes) min"
        }
        return "\(seconds) sec"
    }
}
```

```swift
// FILE: FocusTimerViewModel.swift
import Foundation
import Observation
import UIKit

@Observable
final class FocusTimerViewModel {
    enum Phase: Equatable {
        case idle, running, paused, finished
    }

    var phase: Phase = .idle
    var title: String = "Focus"
    var plannedDuration: TimeInterval = 25 * 60
    var remaining: TimeInterval = 25 * 60

    private var endDate: Date = .now
    private var timer: Timer?
    private var onSessionEnded: ((TimeInterval, Bool) -> Void)?
    private var foregroundObserver: NSObjectProtocol?

    /// Fraction of the ring that is still filled (1 = full, 0 = empty).
    var progress: Double {
        guard plannedDuration > 0 else { return 0 }
        return min(1, max(0, remaining / plannedDuration))
    }

    init() {
        // Re-sync against the wall clock when the app returns to the foreground,
        // since scheduled timers do not fire while backgrounded.
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resync()
        }
    }

    deinit {
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
        timer?.invalidate()
    }

    /// Called by the view to receive finished / ended-early sessions.
    func attach(onSessionEnded: @escaping (TimeInterval, Bool) -> Void) {
        self.onSessionEnded = onSessionEnded
    }

    func selectDuration(_ duration: TimeInterval) {
        guard phase == .idle else { return }
        plannedDuration = duration
        remaining = duration
    }

    func start() {
        guard phase == .idle || phase == .paused else { return }
        if phase == .idle {
            remaining = plannedDuration
        }
        endDate = Date().addingTimeInterval(remaining)
        phase = .running
        scheduleTimer()
    }

    func pause() {
        guard phase == .running else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        invalidateTimer()
        phase = .paused
    }

    /// End the session now and record it as incomplete.
    func endEarly() {
        guard phase == .running || phase == .paused else { return }
        let elapsed = max(1, plannedDuration - remaining)
        invalidateTimer()
        onSessionEnded?(elapsed, false)
        phase = .idle
        remaining = plannedDuration
    }

    /// Discard the current run without recording anything.
    func reset() {
        invalidateTimer()
        phase = .idle
        remaining = plannedDuration
    }

    /// Called after the celebration is dismissed.
    func dismissFinished() {
        phase = .idle
        remaining = plannedDuration
    }

    /// Recompute remaining time from the wall clock (background-safe).
    func resync() {
        guard phase == .running else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 {
            complete()
        }
    }

    private func scheduleTimer() {
        invalidateTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 {
            complete()
        }
    }

    private func complete() {
        invalidateTimer()
        remaining = 0
        phase = .finished
        onSessionEnded?(plannedDuration, true)
    }
}
```

```swift
// FILE: ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Timer", systemImage: "timer") {
                TimerView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath") {
                HistoryView()
            }
        }
    }
}
```

```swift
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
```

```swift
// FILE: CountdownRingView.swift
import SwiftUI

struct CountdownRingView: View {
    let progress: Double
    let remaining: TimeInterval
    let phase: FocusTimerViewModel.Phase
    let title: String

    private let ringDiameter: CGFloat = 280
    private let lineWidth: CGFloat = 16

    private var isRunning: Bool { phase == .running }

    var body: some View {
        ZStack {
            ticks
            track
            progressRing
            centerContent
        }
        .frame(width: 340, height: 340)
    }

    private var track: some View {
        Circle()
            .stroke(
                Color.primary.opacity(0.08),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: ringDiameter, height: ringDiameter)
    }

    private var progressRing: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                AngularGradient(
                    colors: [.green, .mint, .teal, .cyan],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: ringDiameter, height: ringDiameter)
            .rotationEffect(.degrees(-90))
            .shadow(color: .green.opacity(isRunning ? 0.45 : 0.15), radius: isRunning ? 24 : 8)
            .animation(.easeInOut(duration: 0.5), value: isRunning)
            .animation(
                (phase == .running || phase == .paused)
                    ? .linear(duration: 0.12)
                    : .smooth(duration: 0.5),
                value: progress
            )
    }

    private var ticks: some View {
        let tickRadius = ringDiameter / 2 + 16
        return ForEach(0..<60) { index in
            let isMajor = index % 5 == 0
            let elapsed = Double(index) / 60 <= 1 - progress
            Rectangle()
                .fill(Color.primary.opacity(elapsed ? 0.4 : 0.12))
                .frame(width: isMajor ? 2.5 : 1.2, height: isMajor ? 12 : 7)
                .offset(y: -tickRadius)
                .rotationEffect(.degrees(Double(index) * 6))
        }
    }

    private var centerContent: some View {
        VStack(spacing: 6) {
            Text(title.isEmpty ? "Focus" : title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal)

            Text(Formatters.mmss(remaining))
                .font(.system(size: 66, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)

            Text(statusLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isRunning ? .green : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: .capsule)
        }
    }

    private var statusLabel: String {
        switch phase {
        case .idle: return "Ready"
        case .running: return "Focusing…"
        case .paused: return "Paused"
        case .finished: return "Done"
        }
    }
}
```

```swift
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
```

```swift
// FILE: CelebrationView.swift
import SwiftUI

struct CelebrationView: View {
    let duration: TimeInterval
    let onDismiss: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 18) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: appeared)

                Text("Session complete")
                    .font(.title2.bold())

                Text("You focused for \(Formatters.long(duration)).")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Done") {
                    onDismiss()
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding(.top, 6)
            }
            .padding(36)
            .frame(maxWidth: 340)
            .glassEffect(in: .rect(cornerRadius: 32))
            .scaleEffect(appeared ? 1 : 0.75)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                    appeared = true
                }
            }
        }
    }
}
```

```swift
// FILE: HistoryView.swift
import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var sessions: [FocusSession]
    @State private var confirmClear = false

    private var totalTime: TimeInterval {
        sessions.reduce(0) { $0 + $1.actualDuration }
    }

    private var weekTime: TimeInterval {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return sessions
            .filter { $0.startedAt >= weekStart }
            .reduce(0) { $0 + $1.actualDuration }
    }

    var body: some View {
        NavigationStack {
            List {
                if !sessions.isEmpty {
                    Section {
                        HStack(spacing: 0) {
                            stat("\(sessions.count)", "sessions")
                            Divider()
                            stat(Formatters.long(totalTime), "total")
                            Divider()
                            stat(Formatters.long(weekTime), "this week")
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section("Past sessions") {
                    ForEach(sessions) { session in
                        SessionRowView(session: session)
                    }
                    .onDelete(perform: delete)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !sessions.isEmpty {
                        Button("Clear", role: .destructive) { confirmClear = true }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !sessions.isEmpty {
                        EditButton()
                    }
                }
            }
            .confirmationDialog(
                "Delete all \(sessions.count) sessions?",
                isPresented: $confirmClear,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) { clearAll() }
                Button("Cancel", role: .cancel) { }
            }
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "clock.badge.checkmark",
                        description: Text("Complete a focus session and it will appear here.")
                    )
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func delete(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(sessions[offset])
        }
    }

    private func clearAll() {
        for session in sessions {
            modelContext.delete(session)
        }
    }
}
```

```swift
// FILE: SessionRowView.swift
import SwiftUI

struct SessionRowView: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: session.wasCompleted ? "checkmark.circle.fill" : "stop.circle.fill")
                .font(.title2)
                .foregroundStyle(session.wasCompleted ? .green : .orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.subheadline.weight(.semibold))
                Text(session.startedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.long(session.actualDuration))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(session.wasCompleted ? "completed" : "ended early")
                    .font(.caption2)
                    .foregroundStyle(session.wasCompleted ? .secondary : .orange)
            }
        }
        .padding(.vertical, 6)
    }
}
```

**Highlights of the implementation:**

- **Animated countdown ring** — a gradient `Circle().trim(...)` with rounded caps, 60 tick marks that fill as time elapses, a glow that intensifies while running, and `contentTransition(.numericText())` for smoothly rolling digits.
- **iOS 26 Liquid Glass** — `.glassEffect` / `GlassEffectContainer` with `glassEffectID` morphing on the duration presets, `.buttonStyle(.glassProminent)` / `.glass` buttons, and the new glass tab bar.
- **Drift-free timing** — the countdown is computed from a target `endDate` rather than decrementing, and re-syncs on `didBecomeActive`, so backgrounding never loses time.
- **History** — SwiftData `@Model` persisted sessions with `@Query`, swipe-to-delete, edit mode, clear-all confirmation, a stats header (count / total / this week), and an empty state via `ContentUnavailableView`. Ending a session early records it as "ended early" in orange.