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
