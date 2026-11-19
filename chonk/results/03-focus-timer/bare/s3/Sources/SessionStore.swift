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
