import Foundation

struct DayStats: Codable {
    var workSeconds: Int
    var pomodoroCount: Int
}

final class StatsStore {
    private let defaults: UserDefaults
    private let key: String
    private let calendar: Calendar

    init(
        defaults: UserDefaults = .standard,
        key: String = "statsByDay",
        calendar: Calendar = .current
    ) {
        self.defaults = defaults
        self.key = key
        self.calendar = calendar
    }

    func addWorkSeconds(_ seconds: Int) {
        guard seconds > 0 else { return }
        updateForToday { stats in
            stats.workSeconds += seconds
        }
    }

    func incrementPomodoro() {
        updateForToday { stats in
            stats.pomodoroCount += 1
        }
    }

    func statsForToday() -> DayStats {
        let dateKey = dayKey(for: Date())
        let all = loadAll()
        return all[dateKey] ?? DayStats(workSeconds: 0, pomodoroCount: 0)
    }

    private func updateForToday(_ mutate: (inout DayStats) -> Void) {
        let dateKey = dayKey(for: Date())
        var all = loadAll()
        var stats = all[dateKey] ?? DayStats(workSeconds: 0, pomodoroCount: 0)
        mutate(&stats)
        all[dateKey] = stats
        saveAll(all)
    }

    private func dayKey(for date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func loadAll() -> [String: DayStats] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: DayStats].self, from: data)) ?? [:]
    }

    private func saveAll(_ all: [String: DayStats]) {
        if let data = try? JSONEncoder().encode(all) {
            defaults.set(data, forKey: key)
        }
    }

    func clearAll() {
        defaults.removeObject(forKey: key)
    }

    func allStats() -> [String: DayStats] {
        return loadAll()
    }

    func totalStats() -> DayStats {
        let all = loadAll()
        var totalWorkSeconds = 0
        var totalPomodoroCount = 0
        for (_, stats) in all {
            totalWorkSeconds += stats.workSeconds
            totalPomodoroCount += stats.pomodoroCount
        }
        return DayStats(workSeconds: totalWorkSeconds, pomodoroCount: totalPomodoroCount)
    }

    func averageStats() -> (avgWorkSeconds: Double, avgPomodoroCount: Double, dayCount: Int) {
        let all = loadAll()
        let count = all.count
        guard count > 0 else {
            return (0, 0, 0)
        }
        var totalWorkSeconds = 0
        var totalPomodoroCount = 0
        for (_, stats) in all {
            totalWorkSeconds += stats.workSeconds
            totalPomodoroCount += stats.pomodoroCount
        }
        return (
            avgWorkSeconds: Double(totalWorkSeconds) / Double(count),
            avgPomodoroCount: Double(totalPomodoroCount) / Double(count),
            dayCount: count
        )
    }
}
