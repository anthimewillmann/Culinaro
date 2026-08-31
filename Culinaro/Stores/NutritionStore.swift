import Foundation
import Combine

@MainActor
final class NutritionStore: ObservableObject {
    @Published private(set) var loggedMeals: [LoggedMeal] = []
    @Published private(set) var syncError: String?

    private let storageKey = "culinaro.nutrition.loggedMeals"
    private let cloud: CloudKitManager
    private let calendar: Calendar
    /// IDs deleted locally whose CloudKit deletion may not have propagated
    /// yet — siehe RecipeStore für die ausführliche Begründung.
    private var pendingDeletionIDs: Set<UUID> = []
    /// IDs mit einer lokalen Änderung, deren Upload noch nicht bestätigt ist
    /// — siehe RecipeStore für die ausführliche Begründung.
    private var pendingUploadIDs: Set<UUID> = []
    /// Laufende Upload-Tasks pro ID — siehe RecipeStore für die ausführliche
    /// Begründung (verhindert, dass ein Upload einen gelöschten Datensatz
    /// wiederauferstehen lässt; relevant z. B. beim Löschen einer Mahlzeit
    /// direkt aus der History, Sekunden nachdem sie geloggt wurde).
    private var pendingUploadTasks: [UUID: Task<Void, Never>] = [:]

    var caloriesToday: Int {
        loggedMeals
            .filter { calendar.isDateInToday($0.loggedAt) }
            .reduce(0) { $0 + $1.calories }
    }

    var proteinToday: Double { macroToday(\.proteinGrams) }
    var carbsToday: Double { macroToday(\.carbsGrams) }
    var fatToday: Double { macroToday(\.fatGrams) }

    var averageLastSevenDays: AverageNutrition {
        averageNutrition(forLast: 7)
    }

    var averageLastThirtyDays: AverageNutrition {
        averageNutrition(forLast: 30)
    }

    var recentLoggedMeals: [LoggedMeal] {
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: today),
              let endDate = calendar.date(byAdding: .day, value: 1, to: today) else {
            return []
        }

        return loggedMeals
            .filter { $0.loggedAt >= startDate && $0.loggedAt < endDate }
            .sorted { $0.loggedAt > $1.loggedAt }
    }

    init(cloud: CloudKitManager? = nil, calendar: Calendar = .current) {
        self.cloud = cloud ?? .shared
        self.calendar = calendar
        loadCache()
        Task { await syncFromCloud() }
    }

    func logMeal(recipe: Recipe, servings: Double, loggedAt: Date = Date()) {
        guard servings > 0, let nutrition = recipe.nutrition else { return }

        let loggedMeal = LoggedMeal(
            recipeID: recipe.id,
            recipeTitle: recipe.title,
            servingsEaten: servings,
            calories: Int(Double(nutrition.calories ?? 0) * servings),
            proteinGrams: (nutrition.proteinGrams ?? 0) * servings,
            carbsGrams: (nutrition.carbsGrams ?? 0) * servings,
            fatGrams: (nutrition.fatGrams ?? 0) * servings,
            loggedAt: loggedAt
        )
        loggedMeals.append(loggedMeal)
        persistCache()
        pendingUploadIDs.insert(loggedMeal.id)
        pendingUploadTasks[loggedMeal.id] = Task {
            await upload(loggedMeal)
            pendingUploadIDs.remove(loggedMeal.id)
            pendingUploadTasks.removeValue(forKey: loggedMeal.id)
        }
    }

    func deleteMeal(_ loggedMeal: LoggedMeal) {
        loggedMeals.removeAll { $0.id == loggedMeal.id }
        pendingDeletionIDs.insert(loggedMeal.id)
        pendingUploadTasks[loggedMeal.id]?.cancel()
        persistCache()
        Task {
            try? await cloud.delete(id: loggedMeal.id)
            pendingDeletionIDs.remove(loggedMeal.id)
        }
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
        guard !Task.isCancelled else { return }
        do { try await cloud.save(loggedMeal); syncError = nil }
        catch { syncError = error.localizedDescription }
    }

    private func merge(local: [LoggedMeal], remote: [LoggedMeal]) -> [LoggedMeal] {
        var values = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for item in remote where !pendingUploadIDs.contains(item.id) {
            values[item.id] = item
        }
        pendingDeletionIDs.forEach { values.removeValue(forKey: $0) }
        return Array(values.values)
    }

    private func macroToday(_ keyPath: KeyPath<LoggedMeal, Double>) -> Double {
        loggedMeals
            .filter { calendar.isDateInToday($0.loggedAt) }
            .reduce(0) { $0 + $1[keyPath: keyPath] }
    }

    private func averageNutrition(forLast dayCount: Int) -> AverageNutrition {
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: 1 - dayCount, to: today),
              let endDate = calendar.date(byAdding: .day, value: 1, to: today) else {
            return .empty
        }

        let meals = loggedMeals.filter { $0.loggedAt >= startDate && $0.loggedAt < endDate }
        let divisor = Double(dayCount)

        return AverageNutrition(
            calories: Double(meals.reduce(0) { $0 + $1.calories }) / divisor,
            proteinGrams: meals.reduce(0) { $0 + $1.proteinGrams } / divisor,
            carbsGrams: meals.reduce(0) { $0 + $1.carbsGrams } / divisor,
            fatGrams: meals.reduce(0) { $0 + $1.fatGrams } / divisor
        )
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
