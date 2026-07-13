import Foundation
import Combine

@MainActor
final class NutritionStore: ObservableObject {
    @Published private(set) var loggedMeals: [LoggedMeal] = []
    @Published private(set) var syncError: String?

    private let storageKey = "culinaro.nutrition.loggedMeals"
    private let cloud: CloudKitManager
    private let calendar: Calendar

    var caloriesToday: Int {
        loggedMeals
            .filter { calendar.isDateInToday($0.loggedAt) }
            .reduce(0) { $0 + $1.calories }
    }

    var proteinToday: Double { macroToday(\.proteinGrams) }
    var carbsToday: Double { macroToday(\.carbsGrams) }
    var fatToday: Double { macroToday(\.fatGrams) }

    var caloriesLastSevenDays: [DailyCalories] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: today) else { return nil }
            return DailyCalories(date: date, calories: calories(on: date))
        }
    }

    var averageLastThirtyDays: AverageNutrition {
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -29, to: today),
              let endDate = calendar.date(byAdding: .day, value: 1, to: today) else {
            return .empty
        }

        let meals = loggedMeals.filter { $0.loggedAt >= startDate && $0.loggedAt < endDate }
        let dayCount = 30.0

        return AverageNutrition(
            calories: Double(meals.reduce(0) { $0 + $1.calories }) / dayCount,
            proteinGrams: meals.reduce(0) { $0 + $1.proteinGrams } / dayCount,
            carbsGrams: meals.reduce(0) { $0 + $1.carbsGrams } / dayCount,
            fatGrams: meals.reduce(0) { $0 + $1.fatGrams } / dayCount
        )
    }

    init(cloud: CloudKitManager? = nil, calendar: Calendar = .current) {
        self.cloud = cloud ?? .shared
        self.calendar = calendar
        loadCache()
        Task { await syncFromCloud() }
    }

    func logMeal(recipe: Recipe, servings: Double) {
        guard servings > 0, let nutrition = recipe.nutrition else { return }

        let loggedMeal = LoggedMeal(
            recipeID: recipe.id,
            recipeTitle: recipe.title,
            servingsEaten: servings,
            calories: Int(Double(nutrition.calories ?? 0) * servings),
            proteinGrams: (nutrition.proteinGrams ?? 0) * servings,
            carbsGrams: (nutrition.carbsGrams ?? 0) * servings,
            fatGrams: (nutrition.fatGrams ?? 0) * servings
        )
        loggedMeals.append(loggedMeal)
        persistCache()
        Task { await upload(loggedMeal) }
    }

    func deleteMeal(_ loggedMeal: LoggedMeal) {
        loggedMeals.removeAll { $0.id == loggedMeal.id }
        persistCache()
        Task { try? await cloud.delete(id: loggedMeal.id) }
    }

    func syncFromCloud() async {
        do {
            let remote = try await cloud.fetchLoggedMeals()
            loggedMeals = merge(local: loggedMeals, remote: remote)
            persistCache()
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func upload(_ loggedMeal: LoggedMeal) async {
        do { try await cloud.save(loggedMeal); syncError = nil }
        catch { syncError = error.localizedDescription }
    }

    private func merge(local: [LoggedMeal], remote: [LoggedMeal]) -> [LoggedMeal] {
        var values = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        remote.forEach { values[$0.id] = $0 }
        return Array(values.values)
    }

    private func macroToday(_ keyPath: KeyPath<LoggedMeal, Double>) -> Double {
        loggedMeals
            .filter { calendar.isDateInToday($0.loggedAt) }
            .reduce(0) { $0 + $1[keyPath: keyPath] }
    }

    private func calories(on date: Date) -> Int {
        loggedMeals
            .filter { calendar.isDate($0.loggedAt, inSameDayAs: date) }
            .reduce(0) { $0 + $1.calories }
    }

    private func persistCache() {
        guard let data = try? JSONEncoder().encode(loggedMeals) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([LoggedMeal].self, from: data) else { return }
        loggedMeals = decoded
    }
}

struct DailyCalories: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let calories: Int
}

struct AverageNutrition: Equatable {
    let calories: Double
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double

    static let empty = AverageNutrition(
        calories: 0,
        proteinGrams: 0,
        carbsGrams: 0,
        fatGrams: 0
    )
}
