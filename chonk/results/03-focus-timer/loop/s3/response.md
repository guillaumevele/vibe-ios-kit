Here is the complete app. Ten files, SwiftUI only, Apple frameworks only, written for iOS 26 / Swift 6 strict concurrency.

```swift
// FILE: FocusTimerApp.swift
import SwiftUI

@main
struct FocusTimerApp: App {
    @State private var model = AppModel(store: FileSessionStore.default)

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
```

```swift
// FILE: Design.swift
import SwiftUI

enum Spacing {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}

enum AppColor {
    static let accent: Color = .blue
}
```

```swift
// FILE: FocusSession.swift
import Foundation

struct FocusSession: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let duration: TimeInterval
    let startedAt: Date
    let endedAt: Date
    let completed: Bool
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

    static var `default`: FileSessionStore {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory
        return FileSessionStore(fileURL: directory.appendingPathComponent("focus-sessions.json"))
    }

    func load() async throws -> [FocusSession] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try await Task { try Data(contentsOf: fileURL) }.value
        return try JSONDecoder().decode([FocusSession].self, from: data)
    }

    func save(_ sessions: [FocusSession]) async throws {
        let data = try JSONEncoder().encode(sessions)
        _ = try await Task { try data.write(to: fileURL, options: .atomic) }.value
    }
}

actor InMemorySessionStore: SessionStore {
    private var sessions: [FocusSession]

    init(sessions: [FocusSession] = []) {
        self.sessions = sessions
    }

    func load() async throws -> [FocusSession] {
        sessions
    }

    func save(_ sessions: [FocusSession]) async throws {
        self.sessions = sessions
    }
}
```

```swift
// FILE: AppModel.swift
import Foundation
import SwiftUI

@Observable
@MainActor
final class AppModel {
    enum Phase: Equatable, Sendable {
        case idle
        case running
        case paused
        case finished(completed: Bool)
    }

    enum HistoryState {
        case loading
        case empty
        case failed(Error)
        case content
    }

    // MARK: - Timer state

    var phase: Phase = .idle
    var durationMinutes: Int = 25
    var duration: TimeInterval = 25 * 60
    var remaining: TimeInterval = 25 * 60
    var progress: Double = 1
    private(set) var endDate: Date = Date().addingTimeInterval(25 * 60)
    private var startedAt: Date = Date()
    private var tickerTask: Task<Void, Never>?

    // MARK: - History state

    var sessions: [FocusSession] = []
    var historyState: HistoryState = .loading
    var sessionToDelete: FocusSession?
    private var historyLoaded = false

    private let store: SessionStore

    init(store: SessionStore) {
        self.store = store
    }

    // MARK: - Timer actions

    func selectDuration(_ minutes: Int) {
        guard case .idle = phase else { return }
        durationMinutes = minutes
        duration = TimeInterval(minutes) * 60
        remaining = duration
        progress = 1
    }

    func start() {
        switch phase {
        case .idle, .finished:
            startedAt = Date()
            endDate = Date().addingTimeInterval(duration)
            remaining = duration
            progress = 1
            phase = .running
            startTicker()
        case .running, .paused:
            break
        }
    }

    func pause() {
        guard case .running = phase else { return }
        applyRemaining()
        tickerTask?.cancel()
        phase = .paused
    }

    func resume() {
        guard case .paused = phase else { return }
        endDate = Date().addingTimeInterval(remaining)
        phase = .running
        startTicker()
    }

    func endSession(completed: Bool) {
        switch phase {
        case .running, .paused:
            tickerTask?.cancel()
            if completed {
                remaining = 0
                progress = 0
            } else {
                applyRemaining()
            }
            phase = .finished(completed: completed)
            Task { await recordSession(completed: completed) }
        case .idle, .finished:
            break
        }
    }

    func resetToIdle() {
        tickerTask?.cancel()
        phase = .idle
        remaining = duration
        progress = 1
    }

    // MARK: - Scene lifecycle

    func handleAppear() {
        if case .running = phase {
            startTicker()
        }
    }

    func handleDisappear() {
        tickerTask?.cancel()
    }

    func handleScenePhase(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            if case .running = phase {
                applyRemaining()
                if remaining <= 0 {
                    endSession(completed: true)
                } else {
                    startTicker()
                }
            }
        case .inactive, .background:
            tickerTask?.cancel()
            if case .running = phase {
                applyRemaining()
            }
        }
    }

    // MARK: - History

    func loadHistory() async {
        historyState = .loading
        do {
            let loaded = try await store.load()
            sessions = loaded.sorted { $0.startedAt > $1.startedAt }
            historyLoaded = true
            historyState = sessions.isEmpty ? .empty : .content
        } catch {
            historyLoaded = false
            historyState = .failed(error)
        }
    }

    func deleteSession(_ session: FocusSession) async {
        sessionToDelete = nil
        guard historyLoaded else { return }
        await persist(sessions.filter { $0.id != session.id })
    }

    func clearHistory() async {
        guard historyLoaded else { return }
        await persist([])
    }

    // MARK: - Private

    private func applyRemaining() {
        remaining = max(0, endDate.timeIntervalSinceNow)
        progress = duration > 0 ? remaining / duration : 0
    }

    private func startTicker() {
        tickerTask?.cancel()
        tickerTask = Task {
            while !Task.isCancelled {
                tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func tick() {
        guard case .running = phase else { return }
        applyRemaining()
        if remaining <= 0 {
            endSession(completed: true)
        }
    }

    private func persist(_ updated: [FocusSession]) async {
        do {
            try await store.save(updated)
            sessions = updated
            historyState = updated.isEmpty ? .empty : .content
        } catch {
            historyState = .failed(error)
        }
    }

    private func recordSession(completed: Bool) async {
        if !historyLoaded {
            do {
                let loaded = try await store.load()
                sessions = loaded.sorted { $0.startedAt > $1.startedAt }
                historyLoaded = true
            } catch {
                // Refuse to write when the store could not be read.
                historyState = .failed(error)
                return
            }
        }
        let session = FocusSession(
            id: UUID(),
            duration: duration,
            startedAt: startedAt,
            endedAt: Date(),
            completed: completed
        )
        var updated = sessions
        updated.insert(session, at: 0)
        await persist(updated)
    }
}
```

```swift
// FILE: ContentView.swift
import Foundation
import SwiftUI

enum Route: Hashable {
    case history
}

struct ContentView: View {
    @State private var model: AppModel
    @State private var path: [Route] = []

    init(model: AppModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack(path: $path) {
            TimerView(model: model)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(value: Route.history) {
                            Label("History", systemImage: "clock")
                        }
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .history:
                        HistoryView(model: model) {
                            path.removeAll()
                        }
                    }
                }
                .task {
                    await model.loadHistory()
                }
        }
    }
}

#Preview {
    ContentView(model: AppModel(store: InMemorySessionStore()))
}

#Preview("History with sessions") {
    let store = InMemorySessionStore(sessions: [
        FocusSession(
            id: UUID(),
            duration: 25 * 60,
            startedAt: Date().addingTimeInterval(-3 * 3600),
            endedAt: Date().addingTimeInterval(-2 * 3600 - 600),
            completed: true
        ),
        FocusSession(
            id: UUID(),
            duration: 15 * 60,
            startedAt: Date().addingTimeInterval(-26 * 3600),
            endedAt: Date().addingTimeInterval(-25 * 3600),
            completed: false
        )
    ])
    return ContentView(model: AppModel(store: store))
}
```

```swift
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
            case .running, .paused:
                Text(
                    timerInterval: DateInterval(start: Date(), end: model.endDate),
                    pauseTime: model.phase == .paused ? Date() : nil,
                    countsDown: true,
                    showsHours: true
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
                        model.selectDuration(newValue)
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
```

```swift
// FILE: TimerRingView.swift
import SwiftUI

struct TimerRingView<Content: View>: View {
    let progress: Double
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let lineWidth: CGFloat = 16
    private let ringSize: CGFloat = 280

    var body: some View {
        let clamped = max(0, min(1, progress))
        ZStack {
            Group {
                Circle()
                    .stroke(Color.secondary.opacity(0.25), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(AppColor.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .linear(duration: 1), value: clamped)
            }
            .accessibilityHidden(true)
            content()
        }
        .frame(width: ringSize, height: ringSize)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Focus timer")
        .accessibilityValue("\(Int(clamped * 100)) percent remaining")
    }
}
```

```swift
// FILE: HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @Bindable var model: AppModel
    let onStartSession: () -> Void
    @State private var showClearConfirmation = false

    init(model: AppModel, onStartSession: @escaping () -> Void) {
        self.model = model
        self.onStartSession = onStartSession
    }

    var body: some View {
        Group {
            switch model.historyState {
            case .loading:
                ProgressView("Loading history")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                ContentUnavailableView {
                    Label("No sessions yet", systemImage: "clock")
                } description: {
                    Text("Finish a focus session and it will appear here.")
                } actions: {
                    Button("Start a session") {
                        onStartSession()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            case .failed(let error):
                ContentUnavailableView {
                    Label("Could not load history", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Your saved sessions were left untouched.")
                    Text(error.localizedDescription)
                        .font(.footnote)
                } actions: {
                    Button("Retry") {
                        Task { await model.loadHistory() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            case .content:
                List(model.sessions) { session in
                    SessionRow(session: session)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                model.sessionToDelete = session
                            }
                        }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("History")
        .task {
            await model.loadHistory()
        }
        .alert(item: $model.sessionToDelete) { session in
            Alert(
                title: Text("Delete this session?"),
                message: Text("This cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    Task { await model.deleteSession(session) }
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Clear all history?", isPresented: $showClearConfirmation) {
            Button("Clear all", role: .destructive) {
                Task { await model.clearHistory() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Every saved session will be deleted. This cannot be undone.")
        }
        .toolbar {
            if case .content = model.historyState {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", role: .destructive) {
                        showClearConfirmation = true
                    }
                }
            }
        }
    }
}
```

```swift
// FILE: SessionRow.swift
import SwiftUI

struct SessionRow: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: session.completed ? "checkmark.circle.fill" : "stop.circle")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(session.completed ? AppColor.accent : Color.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.completed ? "Completed session" : "Ended early")
                    .font(.headline)
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(session.duration / 60)) min")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Spacing.small)
        .accessibilityElement(children: .combine)
    }
}
```

Not verified

I did not compile or run this app. Still needed before shipping:

- A real build in Xcode with Swift 6 language mode to confirm strict-concurrency checking passes (especially the `SessionStore` protocol, the actor-based `InMemorySessionStore`, and the `Task`-inherited `@MainActor` ticker).
- A simulator run to check timer accuracy against the wall clock, pause/resume, ending a session early, and the ring animation smoothness at 1-second ticks.
- A background/foreground pass on a device to confirm the ticker is cancelled on `scenePhase` changes and that time spent in the background is counted correctly on return.
- A VoiceOver pass over the ring (combined element with percent value), the history rows (combined elements), and both destructive alerts.
- A Dynamic Type pass at the largest sizes to confirm the countdown text fits inside the 280-point ring.
- A persistence check across app launches (JSON in Documents) and a corrupted-file check to confirm the failed state appears and saved data is not overwritten.