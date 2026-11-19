Here's a complete, single-target iOS 26 focus timer app built entirely with Apple frameworks — SwiftUI, SwiftData (persistent session history), Observation (`@Observable`), UserNotifications, and AudioToolbox. The ring is driven by a `TimelineView` at ~60fps and the countdown is computed from wall-clock dates, so it stays accurate even if the app is backgrounded.

```swift
// FILE: FocusTimerApp.swift
import SwiftUI
import SwiftData

@main
struct FocusTimerApp: App {
    private static let sharedModelContainer: ModelContainer = {
        let schema = Schema([Session.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create the model container: \(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(Self.sharedModelContainer)
        }
    }
}
```

```swift
// FILE: ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var engine = TimerEngine()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TimerView(engine: $engine)
                .tabItem { Label("Timer", systemImage: "timer") }
                .tag(0)

            HistoryView { duration, title in
                engine.prepareForRepeat(duration: duration, title: title)
                selectedTab = 0
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            .tag(1)
        }
        .tint(Theme.accent)
    }
}
```

```swift
// FILE: Theme.swift
import SwiftUI

enum Theme {
    static let accent: Color = .indigo
    static let track: Color = Color.secondary.opacity(0.15)
    static let glow: Color = Color.cyan.opacity(0.45)

    static let ringGradient = AngularGradient(
        colors: [.cyan, .blue, .indigo, .purple, .pink, .cyan],
        center: .center
    )
}
```

```swift
// FILE: TimeFormat.swift
import Foundation

enum TimeFormat {
    /// "25:00", or "1:30:00" for sessions over an hour.
    static func hms(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    /// "25 min", "1 hr", "1 hr 30 min".
    static func minutes(_ seconds: TimeInterval) -> String {
        let total = Int(seconds / 60)
        if total < 60 { return "\(total) min" }
        let hours = total / 60
        let remainder = total % 60
        return remainder == 0 ? "\(hours) hr" : "\(hours) hr \(remainder) min"
    }

    /// "Today", "Yesterday", or an abbreviated date.
    static func dayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    static func timeLabel(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
```

```swift
// FILE: Session.swift
import Foundation
import SwiftData

/// A recorded focus session, persisted with SwiftData.
@Model
final class Session {
    var title: String
    var plannedDuration: TimeInterval
    var focusedDuration: TimeInterval
    var startedAt: Date
    var endedAt: Date
    var completed: Bool

    init(
        title: String,
        plannedDuration: TimeInterval,
        focusedDuration: TimeInterval,
        startedAt: Date,
        endedAt: Date,
        completed: Bool
    ) {
        self.title = title
        self.plannedDuration = plannedDuration
        self.focusedDuration = focusedDuration
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.completed = completed
    }
}
```

```swift
// FILE: TimerEngine.swift
import Foundation
import Observation

/// Date-based countdown engine. Remaining time is always derived from
/// `endDate`, so the ring stays accurate even if scheduled timers are
/// coalesced while the app is in the background.
@Observable
final class TimerEngine {
    enum State: Equatable {
        case idle
        case running
        case paused
        case finished
    }

    var state: State = .idle
    var title: String = "Focus"
    var totalDuration: TimeInterval = 25 * 60
    var pausedRemaining: TimeInterval = 25 * 60
    private(set) var startedAt: Date?
    private(set) var endDate: Date?

    private var finishTimer: Timer?
    private var onFinish: ((TimeInterval) -> Void)?

    /// Time spent focusing so far.
    var elapsed: TimeInterval {
        min(totalDuration, max(0, totalDuration - remaining()))
    }

    /// Remaining time at a given moment (used by TimelineView for smooth rendering).
    func remaining(at date: Date = Date()) -> TimeInterval {
        switch state {
        case .idle, .paused, .finished:
            return pausedRemaining
        case .running:
            guard let endDate else { return pausedRemaining }
            return max(0, endDate.timeIntervalSince(date))
        }
    }

    func start(duration: TimeInterval, title: String, onFinish: @escaping (TimeInterval) -> Void) {
        totalDuration = duration
        pausedRemaining = duration
        self.title = title
        self.onFinish = onFinish
        startedAt = Date()
        beginRunning()
        state = .running
    }

    func pause() {
        guard state == .running else { return }
        pausedRemaining = remaining()
        stopTimer()
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        beginRunning()
        state = .running
    }

    func cancel() {
        stopTimer()
        state = .idle
        pausedRemaining = totalDuration
    }

    func reset() {
        stopTimer()
        state = .idle
        pausedRemaining = totalDuration
    }

    /// Change the duration while idle (duration picker).
    func selectDuration(_ duration: TimeInterval) {
        guard state == .idle else { return }
        totalDuration = duration
        pausedRemaining = duration
    }

    /// Pre-fill the idle screen from a past session.
    func prepareForRepeat(duration: TimeInterval, title: String) {
        guard state == .idle else { return }
        totalDuration = duration
        pausedRemaining = duration
        self.title = title
    }

    /// Call when the app becomes active again — finishes the session if the
    /// end date passed while the app was suspended.
    func refreshIfNeeded() {
        if state == .running, remaining() <= 0 {
            finish()
        }
    }

    // MARK: - Private

    private func beginRunning() {
        endDate = Date().addingTimeInterval(pausedRemaining)
        scheduleFinish(at: endDate!)
    }

    private func scheduleFinish(at date: Date) {
        finishTimer?.invalidate()
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            self?.handleTimerFire()
        }
        RunLoop.main.add(timer, forMode: .common)
        finishTimer = timer
    }

    private func handleTimerFire() {
        if remaining() <= 0 {
            finish()
        } else {
            // Fired early (e.g. after background suspension) — reschedule.
            scheduleFinish(at: Date().addingTimeInterval(remaining()))
        }
    }

    private func finish() {
        stopTimer()
        pausedRemaining = 0
        state = .finished
        onFinish?(totalDuration)
    }

    private func stopTimer() {
        finishTimer?.invalidate()
        finishTimer = nil
        endDate = nil
    }
}
```

```swift
// FILE: NotificationManager.swift
import Foundation
import UserNotifications

/// Schedules a local notification for when the focus session ends,
/// so completion is signaled even if the app is in the background.
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
        }
    }

    func scheduleCompletion(at date: Date, title: String) {
        let content = UNNotificationContent()
        content.title = "Focus session complete"
        content.body = "“\(title)” is done. Great work!"
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "focus-completion-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelPending() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
```

```swift
// FILE: CountdownRingView.swift
import SwiftUI

/// The animated countdown ring: a track, minute tick marks, and a
/// gradient progress arc with a soft glow. `progress` goes from 1 (full)
/// down to 0 (empty) and is updated every frame by the TimelineView.
struct CountdownRingView: View {
    var progress: CGFloat
    var lineWidth: CGFloat = 16

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                tickMarks(side: side)

                Circle()
                    .stroke(Theme.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                Circle()
                    .trim(from: 0, to: progress > 0 ? max(progress, 0.002) : 0)
                    .stroke(Theme.ringGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Theme.glow, radius: 14)
            }
            .frame(width: side, height: side)
        }
    }

    private func tickMarks(side: CGFloat) -> some View {
        ForEach(0..<60) { index in
            let isMajor = index % 5 == 0
            Rectangle()
                .fill(Color.secondary.opacity(isMajor ? 0.45 : 0.18))
                .frame(width: isMajor ? 2 : 1, height: isMajor ? 10 : 5)
                .offset(y: -(side / 2) + lineWidth + 8)
                .rotationEffect(.degrees(Double(index) * 6))
        }
    }
}
```

```swift
// FILE: DurationPickerView.swift
import SwiftUI
import UIKit

/// Preset chips plus a slider for a custom duration (5–90 minutes, 5-minute steps).
struct DurationPickerView: View {
    @Binding var selection: TimeInterval

    private let presets: [TimeInterval] = [15, 25, 30, 45, 60].map { TimeInterval($0) * 60 }

    var body: some View {
        VStack(spacing: 14) {
            Text("Duration")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        selection = preset
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("\(Int(preset / 60))")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 46, height: 38)
                            .foregroundStyle(selection == preset ? .white : .primary)
                            .background(
                                selection == preset ? Theme.accent : Color.secondary.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Slider(
                value: Binding(
                    get: { selection },
                    set: { selection = ($0 / 300).rounded() * 300 }
                ),
                in: 5 * 60...90 * 60,
                step: 5 * 60
            ) {
                Text("Custom duration")
            }
            .tint(Theme.accent)

            Text("\(Int(selection / 60)) minutes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
    }
}
```

```swift
// FILE: TimerView.swift
import SwiftUI
import SwiftData
import UIKit
import AudioToolbox

struct TimerView: View {
    @Bindable var engine: TimerEngine
    @Environment(\.modelContext) private var modelContext

    private let ringSize: CGFloat = 300

    private var durationBinding: Binding<TimeInterval> {
        Binding(
            get: { engine.totalDuration },
            set: { engine.selectDuration($0) }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    ringArea
                    controls
                }
                .padding(.vertical, 24)
                .padding(.horizontal)
            }
            .navigationTitle("Focus")
            .background {
                LinearGradient(
                    colors: [Theme.accent.opacity(0.14), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .onAppear {
                NotificationManager.shared.requestAuthorization()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                engine.refreshIfNeeded()
            }
        }
    }

    // MARK: - Ring

    private var ringArea: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: engine.state != .running)) { context in
            let remaining = engine.remaining(at: context.date)
            let progress = engine.totalDuration > 0 ? CGFloat(remaining / engine.totalDuration) : 0
            ZStack {
                CountdownRingView(progress: engine.state == .idle ? 1 : progress)
                    .frame(width: ringSize, height: ringSize)
                centerContent(remaining: remaining)
            }
        }
    }

    @ViewBuilder
    private func centerContent(remaining: TimeInterval) -> some View {
        if engine.state == .finished {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(.green)
                Text("Session complete")
                    .font(.title3.weight(.semibold))
            }
        } else {
            VStack(spacing: 6) {
                Text(TimeFormat.hms(remaining))
                    .font(.system(size: 64, weight: .thin, design: .rounded))
                    .monospacedDigit()
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var statusText: String {
        switch engine.state {
        case .idle: return "Ready when you are"
        case .running: return engine.title.isEmpty ? "Focusing…" : engine.title
        case .paused: return "Paused"
        case .finished: return ""
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        switch engine.state {
        case .idle:
            idleControls
        case .running, .paused:
            runningControls
        case .finished:
            EmptyView()
        }
    }

    private var idleControls: some View {
        VStack(spacing: 18) {
            DurationPickerView(selection: durationBinding)

            TextField("Session name", text: $engine.title)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 8)

            Button {
                startSession()
            } label: {
                Label("Start focus", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(.white)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal