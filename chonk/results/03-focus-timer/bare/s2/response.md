Here's a complete SwiftUI focus timer app targeting iOS 26 — an animated countdown ring (gradient arc + tick marks + numeric text transition), glass-effect controls, duration presets, local notifications for background completion, and a persisted history with stats. All Apple frameworks only.

```swift
// FILE: FocusTimerApp.swift
import SwiftUI
import Observation

@main
struct FocusTimerApp: App {
    @State private var store: SessionStore
    @State private var timer: FocusTimerViewModel

    init() {
        let store = SessionStore()
        self._store = State(initialValue: store)
        self._timer = State(initialValue: FocusTimerViewModel(store: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(timer)
        }
    }
}
```

```swift
// FILE: FocusSession.swift
import Foundation

struct FocusSession: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let plannedDuration: TimeInterval
    let actualDuration: TimeInterval
    let startedAt: Date
    let endedAt: Date
    let completed: Bool

    init(
        id: UUID = UUID(),
        title: String,
        plannedDuration: TimeInterval,
        actualDuration: TimeInterval,
        startedAt: Date,
        endedAt: Date,
        completed: Bool
    ) {
        self.id = id
        self.title = title
        self.plannedDuration = plannedDuration
        self.actualDuration = actualDuration
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.completed = completed
    }
}
```

```swift
// FILE: SessionStore.swift
import Foundation
import Observation

@Observable
final class SessionStore {
    private(set) var sessions: [FocusSession] = []

    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = directory.appendingPathComponent("focus-sessions.json")
        load()
    }

    // MARK: - Derived stats

    var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.actualDuration }
    }

    var totalToday: TimeInterval {
        total(since: Calendar.current.startOfDay(for: Date()))
    }

    var totalThisWeek: TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        return total(since: start)
    }

    func total(since date: Date) -> TimeInterval {
        sessions.filter { $0.endedAt >= date }.reduce(0) { $0 + $1.actualDuration }
    }

    // MARK: - Mutations

    func add(_ session: FocusSession) {
        sessions.insert(session, at: 0)
        save()
    }

    func delete(_ session: FocusSession) {
        sessions.removeAll { $0.id == session.id }
        save()
    }

    func clear() {
        sessions.removeAll()
        save()
    }

    // MARK: - Persistence

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            sessions = try decoder.decode([FocusSession].self, from: data)
        } catch {
            sessions = []
        }
    }

    private func save() {
        do {
            let data = try encoder.encode(sessions)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best effort — history is non-critical.
        }
    }
}
```

```swift
// FILE: Formatters.swift
import Foundation

enum FocusFormat {
    /// "MM:SS" (or "H:MM:SS" for long sessions) for the countdown display.
    static func countdown(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Compact human duration, e.g. "1h 25m", "45m", "30s".
    static func duration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(total)s"
    }
}
```

```swift
// FILE: FocusNotificationService.swift
import Foundation
import UserNotifications

final class FocusNotificationService {
    private let center = UNUserNotificationCenter.current()
    private let identifier = "com.focustimer.session-complete"

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleCompletion(at date: Date, title: String) {
        cancel()
        let content = UNMutableNotificationContent()
        content.title = "Focus session complete"
        content.body = "\"\(title)\" is done — nice work!"
        content.sound = .default
        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
```

```swift
// FILE: FocusTimerViewModel.swift
import Foundation
import Observation
import UIKit

enum TimerPhase: Equatable, Sendable {
    case idle
    case running
    case paused
    case finished
}

@Observable
final class FocusTimerViewModel {
    // MARK: - Configuration

    let presets: [TimeInterval] = [5, 10, 15, 25, 45, 60].map { $0 * 60 }

    var title: String = "Deep work"

    var selectedDuration: TimeInterval = 25 * 60 {
        didSet {
            if phase == .idle {
                remaining = selectedDuration
            }
        }
    }

    // MARK: - State

    private(set) var phase: TimerPhase = .idle
    private(set) var remaining: TimeInterval = 25 * 60

    // MARK: - Derived values

    var progress: Double {
        guard selectedDuration > 0 else { return 0 }
        return min(1, max(0, remaining / selectedDuration))
    }

    var isActive: Bool {
        phase == .running || phase == .paused
    }

    var timeText: String {
        FocusFormat.countdown(remaining)
    }

    var subtitle: String {
        switch phase {
        case .idle: return "\(Int(selectedDuration / 60)) min session"
        case .running: return "Stay focused"
        case .paused: return "Paused"
        case .finished: return "Done"
        }
    }

    // MARK: - Private

    private var endDate: Date?
    private var ticker: Timer?
    private let store: SessionStore
    private let notifications = FocusNotificationService()

    init(store: SessionStore) {
        self.store = store
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        ticker?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Controls

    func selectDuration(_ duration: TimeInterval) {
        selectedDuration = duration
    }

    func start() {
        remaining = selectedDuration
        begin()
    }

    func pause() {
        guard phase == .running, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        phase = .paused
        stopTicker()
        notifications.cancel()
    }

    func resume() {
        guard phase == .paused else { return }
        begin()
    }

    func reset() {
        stopTicker()
        notifications.cancel()
        phase = .idle
        remaining = selectedDuration
        endDate = nil
    }

    /// Ends the session now and records the elapsed time as a partial session.
    func endEarly() {
        guard isActive else { return }
        recordSession(actual: selectedDuration - remaining, completed: false)
        finish()
    }

    func requestNotificationAuthorization() {
        notifications.requestAuthorization()
    }

    /// Recomputes remaining time from the wall clock (e.g. after returning from background).
    func syncWithClock() {
        guard phase == .running, let endDate else { return }
        let left = endDate.timeIntervalSinceNow
        if left <= 0 {
            remaining = 0
            complete()
        } else {
            remaining = left
        }
    }

    // MARK: - Private

    private var resolvedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Focus session" : trimmed
    }

    private func begin() {
        phase = .running
        endDate = Date().addingTimeInterval(remaining)
        startTicker()
        notifications.scheduleCompletion(at: endDate!, title: resolvedTitle)
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard phase == .running, let endDate else { return }
        let left = endDate.timeIntervalSinceNow
        if left <= 0 {
            remaining = 0
            complete()
        } else {
            remaining = left
        }
    }

    private func complete() {
        stopTicker()
        notifications.cancel()
        recordSession(actual: selectedDuration, completed: true)
        finish()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func finish() {
        stopTicker()
        notifications.cancel()
        remaining = 0
        phase = .finished
        endDate = nil
    }

    private func recordSession(actual: TimeInterval, completed: Bool) {
        let now = Date()
        let elapsed = max(0, actual)
        store.add(FocusSession(
            title: resolvedTitle,
            plannedDuration: selectedDuration,
            actualDuration: elapsed,
            startedAt: now.addingTimeInterval(-elapsed),
            endedAt: now,
            completed: completed
        ))
    }

    @objc private func handleDidBecomeActive() {
        syncWithClock()
    }
}
```

```swift
// FILE: TimerRingView.swift
import SwiftUI

struct TimerRingView: View {
    let progress: Double
    let timeText: String
    let subtitle: String
    let phase: TimerPhase
    var accent: Color = .accentColor

    private let lineWidth: CGFloat = 16
    private let tickCount = 60

    var body: some View {
        ZStack {
            tickRing

            // Track
            Circle()
                .stroke(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            // Animated countdown arc (shrinks as time elapses)
            Circle()
                .trim(from: 0, to: progress > 0 ? CGFloat(progress) : 0)
                .stroke(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: accent.opacity(0.4), radius: 16, y: 6)
                .animation(.linear(duration: 0.12), value: progress)

            // Center content
            VStack(spacing: 8) {
                Text(timeText)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(phase == .finished ? .secondary : .primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if phase == .finished {
                    Label("Saved to history", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(width: 320, height: 320)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: phase)
    }

    private var tickRing: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - lineWidth - 8
            let elapsed = 1 - min(1, max(0, progress))

            for i in 0..<tickCount {
                let fraction = Double(i) / Double(tickCount)
                let radians = (fraction * 360 - 90) * .pi / 180
                let cosR = CGFloat(cos(radians))
                let sinR = CGFloat(sin(radians))
                let isElapsed = fraction <= elapsed
                let innerRadius = radius
                let outerRadius = radius + (isElapsed ? 7 : 5)

                var path = Path()
                path.move(to: CGPoint(x: center.x + innerRadius * cosR, y: center.y + innerRadius * sinR))
                path.addLine(to: CGPoint(x: center.x + outerRadius * cosR, y: center.y + outerRadius * sinR))

                context.stroke(
                    path,
                    with: .color(isElapsed ? accent.opacity(0.9) : Color.primary.opacity(0.15)),
                    lineWidth: isElapsed ? 2.5 : 1.5
                )
            }
        }
    }
}
```

```swift
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
```

```swift
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
```

```swift
// FILE: SessionHistoryView.swift
import SwiftUI
import Observation

struct SessionHistoryView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    HistoryStat(title: "Today", value: FocusFormat.duration(store.totalToday))
                    HistoryStat(title: "Week", value: FocusFormat.duration(store.totalThisWeek))
                    HistoryStat(title: "All time", value: FocusFormat.duration(store.totalDuration))
                }
                .listRowBackground(Color.clear)
            }

            ForEach(grouped, id: \.day) { group in
                Section(header: Text(sectionTitle(for: group.day))) {
                    ForEach(group.sessions) { session in
                        HistoryRowView(session: session)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    store.delete(session)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !store.sessions.isEmpty {
                    Menu {
                        Button(role: .destructive) {
                            store.clear()
                        } label: {
                            Label("Clear all", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .overlay {
            if store.sessions.isEmpty {
                ContentUnavailableView(
                    "No sessions yet",
                    systemImage: "clock.badge.checkmark",
                    description: Text("Finish a focus session and it will appear here.")
                )
            }
        }
    }

    private var grouped: [(day: Date, sessions: [FocusSession])] {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: store.sessions) { calendar.startOfDay(for: $0.endedAt) }
        return byDay
            .map { (day: $0.key, sessions: $0.value.sorted { $1.endedAt < $0.endedAt }) }
            .sorted { $0.day > $1.day }
    }

    private func sectionTitle(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct HistoryStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
```

```swift
// FILE: HistoryRowView.swift
import SwiftUI

struct HistoryRowView: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.completed ? "checkmark.circle.fill" : "stop.circle.fill")
                .font(.title2)
                .foregroundStyle(session.completed ? .green : .orange)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.headline)
                Text(timeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(FocusFormat.duration(session.actualDuration))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(session.completed ? "Completed" : "Ended early")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: session.startedAt)) – \(formatter.string(from: session.endedAt))"
    }
}
```

Key details: the countdown is driven by a wall-clock `endDate` (recomputed on foreground via `scenePhase`/`didBecomeActive`), so it stays accurate when the app is backgrounded, with a `UserNotifications` trigger firing if the session finishes while suspended. Completed and early-ended sessions are recorded to a JSON store in the documents directory and shown grouped by day in the history sheet.