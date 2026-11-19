Here's a complete SwiftUI focus timer app targeting iOS 26 (Liquid Glass via `.glassEffect` / `.glass` button styles, `TabView` with value-based tabs, `Charts` for the weekly summary, `UserNotifications` for background completion, and JSON persistence in Application Support). Drop these nine files into a single iOS app target with deployment target iOS 26:

```swift
// FILE: FocusTimerApp.swift
import SwiftUI

@main
struct FocusTimerApp: App {
    @StateObject private var store: SessionStore
    @StateObject private var engine: TimerEngine

    init() {
        let store = SessionStore()
        _store = StateObject(wrappedValue: store)
        _engine = StateObject(wrappedValue: TimerEngine(store: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView(engine: engine, store: store)
        }
    }
}
```

```swift
// FILE: RootView.swift
import SwiftUI
import UIKit

enum RootTab: Hashable {
    case focus
    case history
}

struct RootView: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var store: SessionStore
    @State private var selection: RootTab = .focus

    var body: some View {
        TabView(selection: $selection) {
            Tab("Focus", systemImage: "timer", value: RootTab.focus) {
                ContentView(engine: engine) {
                    selection = .history
                }
            }
            Tab("History", systemImage: "clock.arrow.circlepath", value: RootTab.history) {
                HistoryView()
            }
        }
        .environmentObject(store)
        .onAppear { engine.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // The countdown is end-date based, so it stays correct across backgrounding;
            // this just completes an overdue timer as soon as we're active again.
            engine.refresh()
        }
    }
}
```

```swift
// FILE: TimerEngine.swift
import Foundation

@MainActor
final class TimerEngine: ObservableObject {
    enum State: Equatable {
        case idle
        case running
        case paused
        case finished
    }

    @Published private(set) var state: State = .idle
    @Published var duration: TimeInterval = 25 * 60
    @Published private(set) var remaining: TimeInterval = 25 * 60
    @Published private(set) var completedSession: FocusSession?

    private var startDate: Date?
    private var endDate: Date?
    private var ticker: Timer?
    private let store: SessionStore

    init(store: SessionStore) {
        self.store = store
    }

    var isRunning: Bool { state == .running }

    var stateLabel: String {
        switch state {
        case .idle: return "Ready when you are"
        case .running: return "Focusing"
        case .paused: return "Paused"
        case .finished: return "Session complete"
        }
    }

    /// Remaining time evaluated at an arbitrary date, so the ring can animate smoothly
    /// from a TimelineView without depending on the 0.2 s ticker.
    func remaining(at date: Date) -> TimeInterval {
        switch state {
        case .running:
            return max(0, (endDate ?? date).timeIntervalSince(date))
        case .paused, .finished:
            return remaining
        case .idle:
            return duration
        }
    }

    func progress(at date: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, remaining(at: date) / duration))
    }

    func setDuration(_ newDuration: TimeInterval) {
        guard state == .idle || state == .finished else { return }
        duration = max(60, newDuration)
        remaining = duration
    }

    func start() {
        switch state {
        case .running:
            return
        case .paused:
            endDate = Date.now + remaining
        case .idle, .finished:
            startDate = Date.now
            remaining = duration
            endDate = Date.now + duration
        }
        state = .running
        startTicker()
        FocusNotifier.scheduleCompletion(in: remaining(at: Date.now))
    }

    func pause() {
        guard state == .running else { return }
        remaining = remaining(at: Date.now)
        endDate = nil
        state = .paused
        stopTicker()
        FocusNotifier.cancel()
    }

    func reset() {
        stopTicker()
        FocusNotifier.cancel()
        startDate = nil
        endDate = nil
        remaining = duration
        completedSession = nil
        state = .idle
    }

    /// Completes the timer if it expired while the app was inactive.
    func refresh() {
        guard state == .running, let endDate, endDate <= Date.now else { return }
        complete()
    }

    private func startTicker() {
        stopTicker()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .running,
                      let endDate = self.endDate, endDate <= Date.now else { return }
                self.complete()
            }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func complete() {
        stopTicker()
        FocusNotifier.cancel()
        let endedAt = Date.now
        let session = FocusSession(
            duration: duration,
            startedAt: startDate ?? endedAt,
            endedAt: endedAt
        )
        store.add(session)
        completedSession = session
        remaining = 0
        startDate = nil
        endDate = nil
        state = .finished
    }
}

func formatClock(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded()))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%02d:%02d", minutes, secs)
}
```

```swift
// FILE: FocusSession.swift
import Foundation

struct FocusSession: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let duration: TimeInterval
    let startedAt: Date
    let endedAt: Date

    init(id: UUID = UUID(), duration: TimeInterval, startedAt: Date, endedAt: Date) {
        self.id = id
        self.duration = duration
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    var minutes: Int { max(1, Int(duration / 60)) }
}

extension FocusSession {
    var timeRange: String {
        let style = Date.FormatStyle().hour().minute()
        return "\(startedAt.formatted(style)) – \(endedAt.formatted(style))"
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 && minutes > 0 { return "\(hours) hr \(minutes) min" }
        if hours > 0 { return "\(hours) hr" }
        if minutes > 0 { return "\(minutes) min" }
        return "\(total) sec"
    }
}
```

```swift
// FILE: SessionStore.swift
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [FocusSession] = []

    private let fileURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        fileURL = support.appendingPathComponent("focus-sessions.json")
        load()
    }

    func add(_ session: FocusSession) {
        sessions.insert(session, at: 0)
        save()
    }

    func remove(_ session: FocusSession) {
        sessions.removeAll { $0.id == session.id }
        save()
    }

    /// Offsets are relative to the section for `day` shown in the history list.
    func remove(at offsets: IndexSet, in day: Date) {
        let calendar = Calendar.current
        guard let group = groupedByDay().first(where: { calendar.isDate($0.date, inSameDayAs: day) }) else { return }
        let ids = Set(offsets.compactMap { group.sessions.indices.contains($0) ? group.sessions[$0].id : nil })
        sessions.removeAll { ids.contains($0.id) }
        save()
    }

    func clear() {
        sessions.removeAll()
        save()
    }

    var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    var todayTotal: TimeInterval {
        sessions.filter { Calendar.current.isDateInToday($0.endedAt) }
            .reduce(0) { $0 + $1.duration }
    }

    var weekTotal: TimeInterval {
        sessions.filter { Calendar.current.isDate($0.endedAt, equalTo: .now, toGranularity: .weekOfYear) }
            .reduce(0) { $0 + $1.duration }
    }

    func groupedByDay() -> [(date: Date, sessions: [FocusSession])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.endedAt) }
        return groups
            .map { (date: $0.key, sessions: $0.value.sorted { $0.endedAt > $1.endedAt }) }
            .sorted { $0.date > $1.date }
    }

    /// Focus minutes per day for the last `days` days, oldest first — feeds the bar chart.
    func dailyTotals(forLastDays days: Int = 7) -> [(day: Date, minutes: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        return (0..<days).map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let total = sessions
                .filter { calendar.isDate($0.endedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.duration }
            return (day, total / 60)
        }
        .reversed()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([FocusSession].self, from: data) else { return }
        sessions = decoded.sorted { $0.endedAt > $1.endedAt }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
```

```swift
// FILE: FocusNotifier.swift
import UserNotifications

enum FocusNotifier {
    private static let identifier = "focus-timer.session-complete"

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Fires a local notification when the timer ends, e.g. while the app is in the background.
    static func scheduleCompletion(in seconds: TimeInterval) {
        cancel()
        guard seconds > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Focus session complete"
        content.body = "Great work — your timer has finished."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
```

```swift
// FILE: CountdownRingView.swift
import SwiftUI

struct CountdownRingView: View {
    let diameter: CGFloat
    let progress: Double          // 0...1 of the session remaining
    let lineWidth: CGFloat
    var isComplete: Bool = false

    private var centerlineRadius: CGFloat { diameter / 2 }
    private var tickRadius: CGFloat { centerlineRadius + lineWidth / 2 + 6 }
    private var outerSize: CGFloat { diameter + lineWidth + 16 }
    private var shownProgress: CGFloat { isComplete ? 1 : CGFloat(min(1, max(0, progress))) }

    private var colors: [Color] {
        isComplete
            ? [Color.green, Color.mint, Color.green]
            : [Color.cyan, Color.blue, Color.indigo, Color.purple]
    }

    var body: some View {
        ZStack {
            // Minute tick marks around the ring
            ForEach(0..<60) { index in
                Rectangle()
                    .fill(Color.primary.opacity(index % 5 == 0 ? 0.22 : 0.08))
                    .frame(width: index % 5 == 0 ? 2 : 1, height: index % 5 == 0 ? 10 : 6)
                    .offset(y: -tickRadius)
                    .rotationEffect(.degrees(Double(index) * 6))
            }

            ZStack {
                // Track
                Circle()
                    .stroke(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                // Depleting progress arc
                Circle()
                    .trim(from: 0, to: shownProgress)
                    .stroke(
                        AngularGradient(colors: colors, center: .center, startAngle: .degrees(0), endAngle: .degrees(360)),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: (isComplete ? Color.green : Color.blue).opacity(0.5), radius: 16, y: 6)
            }
            .frame(width: diameter, height: diameter)
        }
        .frame(width: outerSize, height: outerSize)
    }
}
```

```swift
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
```

```swift
// FILE: HistoryView.swift
import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var store: SessionStore
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            if store.sessions.isEmpty {
                ContentUnavailableView(
                    "No sessions yet",
                    systemImage: "timer",
                    description: Text("When you complete a focus session, it will show up here.")
                )
                .navigationTitle("History")
            } else {
                List {
                    Section {
                        SummaryCard(store: store)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))

                        WeeklyChartCard(data: store.dailyTotals())
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                    }

                    ForEach(store.groupedByDay(), id: \.date) { group in
                        Section(header: Text(dayTitle(for: group.date))) {
                            ForEach(group.sessions) { session in
                                SessionRow(session: session)
                            }
                            .onDelete { offsets in
                                store.remove(at: offsets, in: group.date)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("History")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear", role: .destructive) { confirmClear = true }
                    }
                }
                .confirmationDialog(
                    "Delete all recorded focus sessions?",
                    isPresented: $confirmClear,
                    titleVisibility: .visible
                ) {
                    Button("Clear all", role: .destructive) { store.clear() }
                    Button("Cancel", role: .cancel) { }
                }
            }
        }
    }

    private func dayTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())
    }
}

private struct SummaryCard: View {
    @ObservedObject var store: SessionStore

    var body: some View {
        VStack(spacing: 14) {
            Text(FocusSession.formatDuration(store.totalDuration))
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text("total focus time")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                stat(title: "Today", value: FocusSession.formatDuration(store.todayTotal))
                Spacer()
                Divider().frame(height: 32)
                Spacer()
                stat(title: "This week", value: FocusSession.formatDuration(store.weekTotal))
                Spacer()
                Divider().frame(height: 32)
                Spacer()
                stat(title: "Sessions", value: "\(store.sessions.count)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .glassEffect(in: .rect(cornerRadius: 24))
    }

    private func stat(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.headline)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct WeeklyChartCard: View {
    let data: [(day: Date, minutes: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 days")
                .font(.headline)

            Chart(data, id: \.day) { item in
                BarMark(
                    x: .value("Day", item.day, unit: .day),
                    y: .value("Minutes", item.minutes)
                )
                .foregroundStyle(LinearGradient(colors: [.cyan, .indigo], startPoint: .top, endPoint: .bottom))
                .cornerRadius(6)
                .annotation(position: .top, alignment: .center) {
                    if item.minutes >= 1 {
                        Text("\(Int(item.minutes))")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 140)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 24))
    }
}

private struct SessionRow: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.cyan, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                Image(systemName: "timer")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Focus session")
                    .font(.subheadline.weight(.semibold))
                Text(session.timeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(session.minutes) min")
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
```

Key design points:

- **Accurate timing**: the engine stores an `endDate` and computes remaining time from `Date.now`, so the countdown stays correct across backgrounding, and a `TimelineView` redraws the ring at ~30 fps for a buttery animation. A 0.2 s ticker only detects completion and saves the session.
- **Animated ring**: `Circle().trim(...)` with an `AngularGradient` stroke, round caps, glow shadow, minute tick marks, and a spring scale + green fill + success haptic when a session finishes.
- **History**: sessions persist as JSON in Application Support, grouped into Today/Yesterday/date sections with swipe-to-delete, a Liquid Glass summary card (total/today/week/count), and a 7-day `Charts` bar chart.
- **iOS 26 polish**: `.glassEffect` cards and pills, `.glass` / `.glassProminent` button styles, value-based `Tab` navigation (with a "View history" shortcut after completion), and a local notification if the timer ends while the app is backgrounded.