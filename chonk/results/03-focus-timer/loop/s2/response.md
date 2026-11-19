Here is the complete app, one file per fenced block.

```swift
// FILE: FocusTimerApp.swift
import SwiftUI

@main
struct FocusTimerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

```swift
// FILE: ContentView.swift
import SwiftUI

enum Spacing {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 32
}

enum Route: Hashable, Sendable {
    case history
}

struct ContentView: View {
    @State private var model: TimerModel
    @Environment(\.scenePhase) private var scenePhase

    @MainActor
    init() {
        _model = State(initialValue: TimerModel(store: FileSessionStore.makeDefault()))
    }

    var body: some View {
        NavigationStack {
            TimerView(model: model)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .history:
                        HistoryView(model: model)
                    }
                }
        }
        .task {
            await model.loadHistoryIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            model.handleScenePhase(newPhase)
        }
    }
}

#Preview {
    ContentView()
}
```

```swift
// FILE: Session.swift
import Foundation

struct Session: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let duration: TimeInterval
    let startedAt: Date
    let completedAt: Date?
}
```

```swift
// FILE: SessionStore.swift
import Foundation

protocol SessionStoring: Sendable {
    func load() async throws -> [Session]
    func save(_ sessions: [Session]) async throws
}

struct FileSessionStore: SessionStoring {
    let url: URL

    static func makeDefault() -> FileSessionStore {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return FileSessionStore(url: directory.appendingPathComponent("focus-sessions.json"))
    }

    static func makePreview() -> FileSessionStore {
        FileSessionStore(url: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("focus-sessions-preview-\(UUID().uuidString).json"))
    }

    func load() async throws -> [Session] {
        let data = try await Task.detached {
            guard FileManager.default.fileExists(atPath: url.path()) else { return nil }
            return try Data(contentsOf: url)
        }.value
        guard let data else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Session].self, from: data)
    }

    func save(_ sessions: [Session]) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sessions)
        try await Task.detached {
            try data.write(to: url, options: .atomic)
        }.value
    }
}
```

```swift
// FILE: TimerModel.swift
import Foundation
import Observation
import SwiftUI

enum HistoryState: Sendable {
    case loading
    case empty
    case failed(HistoryFailure)
    case content([Session])
}

struct HistoryFailure: Sendable, Equatable {
    let message: String
}

struct DurationOption: Identifiable, Hashable, Sendable {
    let minutes: Int

    var id: Int { minutes }

    var label: String { "\(minutes) min" }

    static let all: [DurationOption] = [15, 25, 45, 60].map { DurationOption(minutes: $0) }
}

@Observable
@MainActor
final class TimerModel {
    enum Phase: Sendable {
        case idle
        case running
        case paused
        case finished
    }

    var phase: Phase = .idle
    var selectedMinutes = 25
    var duration: TimeInterval = 25 * 60
    var remaining: TimeInterval = 25 * 60
    var endDate: Date?
    var completedCount = 0
    var notice: String?
    var historyState: HistoryState = .loading

    private(set) var sessions: [Session] = []
    private var startDate: Date = .now
    private var ticker: Task<Void, Never>?
    private let store: SessionStoring
    private var hasLoaded = false
    private var storeReadable = false

    init(store: SessionStoring) {
        self.store = store
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / duration))
    }

    var remainingDescription: String {
        let total = max(0, Int(remaining.rounded()))
        let minutes = total / 60
        let seconds = total % 60
        if minutes > 0 {
            return "\(minutes) minutes and \(seconds) seconds"
        }
        return "\(seconds) seconds"
    }

    var totalMinutes: Int {
        sessions.reduce(0) { $0 + Int($1.duration / 60) }
    }

    // MARK: Timer controls

    func start() {
        guard phase == .idle || phase == .finished else { return }
        duration = TimeInterval(selectedMinutes * 60)
        remaining = duration
        startDate = .now
        endDate = .now.addingTimeInterval(duration)
        notice = nil
        phase = .running
        startTicker()
    }

    func pause() {
        guard phase == .running else { return }
        if let end = endDate {
            remaining = max(0, end.timeIntervalSince(.now))
        }
        stopTicker()
        endDate = nil
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        endDate = .now.addingTimeInterval(remaining)
        phase = .running
        startTicker()
    }

    func reset() {
        stopTicker()
        phase = .idle
        endDate = nil
        remaining = TimeInterval(selectedMinutes * 60)
        duration = remaining
    }

    func handleScenePhase(_ newPhase: ScenePhase) {
        if newPhase == .active {
            if phase == .running && ticker == nil {
                endDate = .now.addingTimeInterval(remaining)
                startTicker()
            }
        } else if phase == .running {
            if let end = endDate {
                remaining = max(0, end.timeIntervalSince(.now))
            }
            stopTicker()
            endDate = nil
        }
    }

    // MARK: History

    func loadHistoryIfNeeded() async {
        guard !hasLoaded else { return }
        await loadHistory()
    }

    func loadHistory() async {
        historyState = .loading
        do {
            let loaded = try await store.load()
            storeReadable = true
            hasLoaded = true
            sessions = loaded.sorted { $0.startedAt > $1.startedAt }
            historyState = sessions.isEmpty ? .empty : .content(sessions)
        } catch {
            storeReadable = false
            hasLoaded = true
            historyState = .failed(HistoryFailure(message: "Past sessions could not be read from storage. Nothing was changed or deleted."))
        }
    }

    func delete(_ session: Session) async {
        sessions.removeAll { $0.id == session.id }
        historyState = sessions.isEmpty ? .empty : .content(sessions)
        await persist()
    }

    // MARK: Private

    private func startTicker() {
        stopTicker()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func tick() {
        guard phase == .running else { return }
        if let end = endDate {
            remaining = max(0, end.timeIntervalSince(.now))
        }
        if remaining <= 0 {
            complete()
        }
    }

    private func complete() {
        stopTicker()
        endDate = nil
        remaining = 0
        phase = .finished
        completedCount += 1
        Task {
            await recordSession()
        }
    }

    private func recordSession() async {
        let session = Session(id: UUID(), duration: duration, startedAt: startDate, completedAt: .now)
        sessions.insert(session, at: 0)
        historyState = sessions.isEmpty ? .empty : .content(sessions)
        await persist()
    }

    private func persist() async {
        guard storeReadable else {
            notice = "This session finished, but it could not be saved because the history has not been read successfully yet. Open History and retry to re-enable saving."
            return
        }
        do {
            try await store.save(sessions)
        } catch {
            storeReadable = false
            notice = "This session finished, but saving the history failed. Saving stays disabled until the history loads successfully."
            historyState = .failed(HistoryFailure(message: "The history could not be saved. Use Retry to reload it, then the change can be saved again."))
        }
    }
}
```

```swift
// FILE: TimerView.swift
import SwiftUI

struct TimerView: View {
    @Bindable var model: TimerModel
    @State private var pendingReset = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.large) {
                ringSection
                controlsSection
                if let notice = model.notice {
                    Label(notice, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.leading)
                        .accessibilityElement(children: .combine)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Focus Timer")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.history) {
                    Label("History", systemImage: "clock")
                }
            }
        }
        .sensoryFeedback(.success, trigger: model.completedCount)
        .alert("Reset the timer?", isPresented: $pendingReset) {
            Button("Reset", role: .destructive) { model.reset() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The current progress will be lost.")
        }
    }

    private var ringSection: some View {
        ZStack {
            CountdownRing(progress: model.progress)
                .frame(width: 280, height: 280)
            VStack(spacing: Spacing.small) {
                Text(phaseTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                timeText
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Countdown")
        .accessibilityValue("\(model.remainingDescription) remaining")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var phaseTitle: String {
        switch model.phase {
        case .idle: return "Ready"
        case .running: return "Focusing"
        case .paused: return "Paused"
        case .finished: return "Session complete"
        }
    }

    private var timeText: some View {
        Group {
            if model.phase == .running, let endDate = model.endDate {
                Text(timerInterval: DateInterval(start: .now, end: endDate), countsDown: true)
            } else {
                Text(clockString(model.remaining))
            }
        }
    }

    private func clockString(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var controlsSection: some View {
        VStack(spacing: Spacing.medium) {
            switch model.phase {
            case .idle:
                durationPicker
                Button {
                    model.start()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minHeight: 44)
            case .running:
                HStack(spacing: Spacing.medium) {
                    Button {
                        model.pause()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(minHeight: 44)
                    resetButton
                }
            case .paused:
                HStack(spacing: Spacing.medium) {
                    Button {
                        model.resume()
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(minHeight: 44)
                    resetButton
                }
            case .finished:
                Button {
                    model.reset()
                } label: {
                    Label("Done", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minHeight: 44)
            }
        }
    }

    private var resetButton: some View {
        Button {
            pendingReset = true
        } label: {
            Label("Reset", systemImage: "arrow.counterclockwise")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(minHeight: 44)
    }

    private var durationPicker: some View {
        Picker("Session length", selection: $model.selectedMinutes) {
            ForEach(DurationOption.all) { option in
                Text(option.label).tag(option.minutes)
            }
        }
        .pickerStyle(.segmented)
        .sensoryFeedback(.selection, trigger: model.selectedMinutes)
    }
}

struct CountdownRing: View {
    let progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let lineWidth: CGFloat = 16

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: lineWidth))
            Circle()
                .trim(from: 0, to: CGFloat(min(1, max(0, progress))))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
        }
    }
}

#Preview {
    NavigationStack {
        TimerView(model: TimerModel(store: FileSessionStore.makePreview()))
    }
}
```

```swift
// FILE: HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @Bindable var model: TimerModel
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDelete: Session?

    var body: some View {
        Group {
            switch model.historyState {
            case .loading:
                loadingView
            case .empty:
                emptyView
            case .failed(let failure):
                failedView(failure)
            case .content(let sessions):
                contentView(sessions)
            }
        }
        .navigationTitle("History")
        .task {
            await model.loadHistoryIfNeeded()
        }
        .alert(
            "Delete this session?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { newValue in if !newValue { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { session in
            Button("Delete", role: .destructive) {
                Task { await model.delete(session) }
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: { _ in
            Text("This cannot be undone.")
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView("Loading history")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No focus sessions yet", systemImage: "clock")
        } description: {
            Text("Complete a focus timer session and it will appear here.")
        } actions: {
            Button("Start a timer") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(minHeight: 44)
        }
    }

    private func failedView(_ failure: HistoryFailure) -> some View {
        ContentUnavailableView {
            Label("History could not be loaded", systemImage: "exclamationmark.triangle")
        } description: {
            Text(failure.message)
        } actions: {
            Button("Retry") {
                Task { await model.loadHistory() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(minHeight: 44)
        }
    }

    private func contentView(_ sessions: [Session]) -> some View {
        List {
            Section {
                ForEach(sessions) { session in
                    row(for: session)
                }
            } header: {
                Text("Total focus time: \(model.totalMinutes) minutes")
            }
        }
        .listStyle(.insetGrouped)
    }

    private func row(for session: Session) -> some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: session.completedAt != nil ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(session.completedAt != nil ? Color.accentColor : Color.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(session.duration / 60)) minute focus session")
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Int(session.duration / 60)) minute focus session, \(session.startedAt.formatted(date: .abbreviated, time: .shortened))")
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                pendingDelete = session
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    let model = TimerModel(store: FileSessionStore.makePreview())
    model.historyState = .content([
        Session(id: UUID(), duration: 1500, startedAt: .now.addingTimeInterval(-3600), completedAt: .now.addingTimeInterval(-1800)),
        Session(id: UUID(), duration: 900, startedAt: .now.addingTimeInterval(-90000), completedAt: .now.addingTimeInterval(-89100))
    ])
    return NavigationStack {
        HistoryView(model: model)
    }
}
```

Not verified

I did not build or run this app. Before shipping it still needs:

- A compile in Xcode against the iOS 26 SDK in Swift 6 mode — especially the `alert(_:isPresented:presenting:actions:message:)` generic constraints and the `@MainActor init()` on `ContentView`.
- A simulator run of both `#Preview`s and the real flow: start, pause, resume, reset (alert), completion, and that a session lands in History and survives an app relaunch (JSON persistence in Application Support).
- A backgrounding check: leave the app mid-session, return, and confirm the remaining time stayed correct and the ticker resumed.
- A VoiceOver pass on the timer ring (value in words, `updatesFrequently`), the combined history rows, the swipe delete, and both alerts.
- A Reduce Motion pass to confirm the ring jumps instantly instead of animating.
- A device test for haptics (`sensoryFeedback`) and for Dynamic Type at the largest sizes, since the ring is a fixed 280-point frame inside a `ScrollView`.
- A failure-path test: make the store unreadable (e.g. corrupt the JSON file) and confirm History shows the failed state with Retry, and that the timer refuses to save until a read succeeds, with the notice visible.