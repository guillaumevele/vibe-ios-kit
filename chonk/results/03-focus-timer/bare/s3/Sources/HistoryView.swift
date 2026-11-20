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
