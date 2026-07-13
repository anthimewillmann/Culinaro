import Foundation
import Combine

@MainActor
final class StatsStore: ObservableObject {
    @Published var completedCookModes: Int { didSet { save() } }
    @Published var completedLessons: Int { didSet { save() } }
    @Published var allergies: String { didSet { save() } }
    @Published var calorieGoal: Int { didSet { save() } }
    @Published private var completionDates: [Date] { didSet { save() } }

    private let defaults: UserDefaults
    private let calendar: Calendar

    var currentStreak: Int {
        let completedDays = Set(completionDates.map { calendar.startOfDay(for: $0) })
        guard !completedDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var day = completedDays.contains(today) ? today : yesterday
        var streak = 0

        while completedDays.contains(day) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previousDay
        }

        return streak
    }

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        completedCookModes = defaults.integer(forKey: "culinaro.stats.cookModes")
        completedLessons = defaults.integer(forKey: "culinaro.stats.lessons")
        allergies = defaults.string(forKey: "culinaro.stats.allergies") ?? ""
        calorieGoal = defaults.integer(forKey: "culinaro.stats.calorieGoal")
        completionDates = defaults.array(forKey: "culinaro.stats.completionDates") as? [Date] ?? []
    }

    func recordCompletion(_ kind: CompletionKind) {
        switch kind {
        case .recipe: completedCookModes += 1
        case .lesson: completedLessons += 1
        }

        completionDates.append(Date())
    }

    private func save() {
        defaults.set(completedCookModes, forKey: "culinaro.stats.cookModes")
        defaults.set(completedLessons, forKey: "culinaro.stats.lessons")
        defaults.set(allergies, forKey: "culinaro.stats.allergies")
        defaults.set(calorieGoal, forKey: "culinaro.stats.calorieGoal")
        defaults.set(completionDates, forKey: "culinaro.stats.completionDates")
    }
}
