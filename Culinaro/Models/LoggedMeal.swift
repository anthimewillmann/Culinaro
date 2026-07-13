import Foundation

struct LoggedMeal: Identifiable, Codable, Equatable {
    let id: UUID
    let recipeID: UUID
    let recipeTitle: String
    let servingsEaten: Double
    let calories: Int
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let loggedAt: Date

    init(
        id: UUID = UUID(),
        recipeID: UUID,
        recipeTitle: String,
        servingsEaten: Double,
        calories: Int,
        proteinGrams: Double = 0,
        carbsGrams: Double = 0,
        fatGrams: Double = 0,
        loggedAt: Date = Date()
    ) {
        self.id = id
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.servingsEaten = servingsEaten
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.loggedAt = loggedAt
    }
}
