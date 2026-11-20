Here is the complete app, one file per block. It assumes a single SwiftUI target on iOS 26, Swift 6 language mode.

```swift
// FILE: FocusTimerApp.swift
import SwiftUI

@main
struct FocusTimerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

```swift
// FILE: RootView.swift
import SwiftUI

enum Route: Hashable {
    case history
}

struct RootView: View {
    @State private var timer: TimerModel
    @State private var history: HistoryModel
    @State private var path = NavigationPath()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = FileSessionStore.default
        _timer = State(initialValue: TimerModel(store: store))
        _history = State(initialValue: HistoryModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $path) {
            TimerView(model: timer, path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .history:
                        HistoryView(model: history)
                    }
                }
                .navigationDestination(for: FocusSession.self) { session in
                    SessionDetailView(session: session)
                }
        }
        .task {
            timer.setSceneActive(scenePhase == .active)
        }
        .onChange(of: scenePhase) { _, newPhase in
            timer.setSceneActive(newPhase == .active)
        }
    }
}
```

```swift
// FILE: Theme.swift
import SwiftUI

enum Theme {
    static let accent: Color = .indigo
}

enum Spacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let ringWidth: CGFloat = 14
    static let ringSize: CGFloat = 260
}
```

```swift
// FILE: FocusSession.swift
import Foundation

struct FocusSession: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let startedAt: Date
    let plannedDuration: TimeInterval
    let completed: Bool
    let endedAt: Date

    var actualDuration: TimeInterval {
        endedAt.timeIntervalSince(startedAt)
    }
}
```

```swift
// FILE: SessionStore.swift
import Foundation

protocol SessionStore: Sendable {
    func load() async throws -> [FocusSession]
    func save(_ sessions: [FocusSession]) async throws
}

struct FileSessionStore: SessionStore {
    let fileURL: URL

    static let `default`: FileSessionStore = {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return FileSessionStore(fileURL: directory.appendingPathComponent("focus-sessions.json"))
    }()

    func load() async throws -> [FocusSession] {
        do {
            let data = try await Data(contentsOf: fileURL, options: .mappedIfSafe)
            return try JSONDecoder().decode([FocusSession].self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        }
    }

    func save(_ sessions: [FocusSession]) async throws {
        let data = try JSONEncoder().encode(sessions)
        try await Task.detached {
            try FileManager.default.createDirectory(
                at: self.fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: self.fileURL, options: .atomic)
        }.value
    }
}

actor MemorySessionStore: SessionStore {
    private var storage: [FocusSession]

    init(sessions: [FocusSession] = []) {
        storage = sessions
    }

    func load() async throws -> [FocusSession] {
        storage
    }

    func save(_ sessions: [FocusSession]) async throws {
        storage = sessions
    }
}
```

```swift
// FILE: TimerModel.swift
import Foundation

@Observable
@MainActor
final class TimerModel {
    enum Phase: Equatable {
        case idle
        case running
        case paused
        case finished
    }

    var selectedMinutes = 25
    var phase: Phase = .idle
    var remaining: TimeInterval = 0
    var endDate: Date?
    var notice: String?

    private let store: any SessionStore
    private var startedAt: Date?
    private var plannedDuration: TimeInterval = 0
    private var ticker: Task<Void, Never>?

    init(store: any SessionStore) {
        self.store = store
        self.remaining = totalDuration
    }

    var totalDuration: TimeInterval {
        Double(selectedMinutes) * 60
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return max(0, min(1, 1 - remaining / totalDuration))
    }

    func syncDuration() {
        if phase == .idle {
            remaining = totalDuration
        }
    }

    func start() {
        startedAt = Date.now
        plannedDuration = totalDuration
        remaining = totalDuration
        endDate = Date.now + totalDuration
        phase = .running
        notice = nil
        startTicker()
    }

    func pause() {
        guard phase == .running, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        phase = .paused
        stopTicker()
    }

    func resume() {
        guard phase == .paused else { return }
        endDate = Date.now + remaining
        phase = .running
        startTicker()
    }

    func reset() {
        stopTicker()
        phase = .idle
        endDate = nil
        startedAt = nil
        remaining = totalDuration
    }

    func endEarly() {
        guard phase == .running else { return }
        stopTicker()
        Task { await self.record(completed: false) }
        phase = .idle
        endDate = nil
        remaining = totalDuration
    }

    func setSceneActive(_ isActive: Bool) {
        if isActive {
            if phase == .running {
                startTicker()
                tick()
            }
        } else {
            stopTicker()
        }
    }

    private func startTicker() {
        stopTicker()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, let self else { return }
                await self.tick()
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func tick() {
        guard phase == .running, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 {
            stopTicker()
            endDate = nil
            phase = .finished
            Task { await self.record(completed: true) }
        }
    }

    private func record(completed: Bool) async {
        guard let startedAt else { return }
        let session = FocusSession(
            id: UUID(),
            startedAt: startedAt,
            plannedDuration: plannedDuration,
            completed: completed,
            endedAt: Date.now
        )
        do {
            let existing = try await store.load()
            try await store.save(existing + [session])
            notice = nil
        } catch {
            notice = "The session finished but could not be saved to history. Open History and choose Retry to reload."
        }
    }
}
```

```swift
// FILE: HistoryModel.swift
import Foundation

@Observable
@MainActor
final class HistoryModel {
    enum LoadState: Equatable {
        case loading
        case empty
        case failed(String)
        case loaded([FocusSession])
    }

    var state: LoadState = .loading
    var notice: String?

    let store: any SessionStore
    private var canWrite = true

    init(store: any SessionStore) {
        self.store = store
    }

    func load() async {
        state = .loading
        do {
            let sessions = try await store.load()
            canWrite = true
            notice = nil
            state = sessions.isEmpty ? .empty : .loaded(sessions.sorted { $0.startedAt > $1.startedAt })
        } catch {
            canWrite = false
            state = .failed("The saved history could not be read, so nothing was changed. Check that storage is available, then choose Retry.")
        }
    }

    func delete(_ session: FocusSession) async {
        guard canWrite, case .loaded(let sessions) = state else { return }
        await persist(sessions.filter { $0.id != session.id })
    }

    func clearAll() async {
        await persist([])
    }

    private func persist(_ sessions: [FocusSession]) async {
        guard canWrite else {
            notice = "Saving is paused until the history loads successfully. Choose Retry first."
            return
        }
        do {
            try await store.save(sessions)
            notice = nil
            state = sessions.isEmpty ? .empty : .loaded(sessions.sorted { $0.startedAt > $1.startedAt })
        } catch {
            notice = "The change could not be saved. The stored history was not modified."
        }
    }
}
```

```swift
// FILE: CountdownRingView.swift
import SwiftUI

struct CountdownRingView: View {
    let progress: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.25), lineWidth: Spacing.ringWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: Spacing.ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 0.2), value: progress)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Ring") {
    CountdownRingView(progress: 0.6)
        .frame(width: Spacing.ringSize, height: Spacing.ringSize)
        .padding()
}
```

```swift
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
```

```swift
// FILE: HistoryView.swift
import SwiftUI
import Foundation

struct HistoryView: View {
    @Bindable var model: HistoryModel
    @Environment(\.dismiss) private var dismiss
    @State private var showClearAlert = false

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView("Loading history")
            case .empty:
                ContentUnavailableView {
                    Label("No focus sessions yet", systemImage: "clock")
                } description: {
                    Text("Finish a focus session and it will appear here.")
                } actions: {
                    Button("Back to timer") {
                        dismiss()
                    }
                }
            case .failed(let message):
                ContentUnavailableView {
                    Label("History could not be loaded", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry", systemImage: "arrow.clockwise") {
                        Task { await model.load() }
                    }
                }
            case .loaded(let sessions):
                sessionList(sessions)
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if case .loaded = model.state {
                    Button("Clear", role: .destructive) {
                        showClearAlert = true
                    }
                }
            }
        }
        .alert("Clear all history?", isPresented: $showClearAlert) {
            Button("Clear", role: .destructive) {
                Task { await model.clearAll() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Every saved session will be removed and this cannot be undone.")
        }
        .task {
            await model.load()
        }
    }

    private func sessionList(_ sessions: [FocusSession]) -> some View {
        List {
            if let notice = model.notice {
                Label(notice, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .listRowBackground(Color.clear)
            }
            ForEach(sessions) { session in
                NavigationLink(value: session) {
                    SessionRow(session: session)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await model.delete(session) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct SessionRow: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: session.completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(session.completed ? .green : .secondary)
                .accessibilityLabel(Text(session.completed ? "Completed" : "Ended early"))
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(Duration.seconds(session.plannedDuration).formatted(.units(allowed: [.minute])))
                    .font(.headline)
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Duration.seconds(session.actualDuration).formatted(.units(allowed: [.minute, .second])))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HistoryPreviewRoot: View {
    @State private var model: HistoryModel

    init() {
        let samples = [
            FocusSession(
                id: UUID(),
                startedAt: Date.now.addingTimeInterval(-3900),
                plannedDuration: 25 * 60,
                completed: true,
                endedAt: Date.now.addingTimeInterval(-1400)
            ),
            FocusSession(
                id: UUID(),
                startedAt: Date.now.addingTimeInterval(-90000),
                plannedDuration: 45 * 60,
                completed: false,
                endedAt: Date.now.addingTimeInterval(-89280)
            )
        ]
        _model = State(initialValue: HistoryModel(store: MemorySessionStore(sessions: samples)))
    }

    var body: some View {
        NavigationStack {
            HistoryView(model: model)
        }
    }
}

#Preview("History") {
    HistoryPreviewRoot()
}
```

```swift
// FILE: SessionDetailView.swift
import SwiftUI
import Foundation

struct SessionDetailView: View {
    let session: FocusSession

    var body: some View {
        List {
            Section {
                Label(
                    session.completed ? "Completed" : "Ended early",
                    systemImage: session.completed ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .foregroundStyle(session.completed ? .green : .secondary)
            }
            Section("Session") {
                LabeledContent("Planned") {
                    Text(Duration.seconds(session.plannedDuration).formatted(.units(allowed: [.minute, .second])))
                }
                LabeledContent("Actual") {
                    Text(Duration.seconds(session.actualDuration).formatted(.units(allowed: [.minute, .second])))
                }
                LabeledContent("Started") {
                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                }
                LabeledContent("Ended") {
                    Text(session.endedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        .navigationTitle("Session")
    }
}
```

Not verified

I did not build or run this app. Before shipping it still needs:

- A compile in Xcode with Swift 6 strict concurrency enabled, to confirm the exact spellings I relied on: the async `Data(contentsOf:options:)` overload, `Text(timerInterval:pauseTime:countsDown:showsHours:)`, `Duration.formatted(.units(allowed:))`, and `LabeledContent` with a content closure.
- A simulator run to check the 200 ms ticker drives the ring smoothly, that pausing/resuming keeps wall-clock accuracy, and that finishing a session writes to the JSON file and appears in History after relaunch.
- A backgrounding test on device: lock the screen mid-session and confirm the ticker stops via `scenePhase` and the remaining time is still correct on return.
- A VoiceOver pass over the timer ring (should announce the remaining time in words), the combined history rows, and the empty/failed states with their action buttons.
- A Dynamic Type pass at `.accessibilityExtraExtraExtraLarge` to confirm the ring label scales and nothing clips, plus a Reduce Motion run to confirm the ring updates without animation.