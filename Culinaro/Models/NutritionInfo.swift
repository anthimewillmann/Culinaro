import Foundation

struct NutritionInfo: Codable, Equatable {
    var calories: Int?
    var proteinGrams: Double?
    var carbsGrams: Double?
    var fatGrams: Double?
    var servings: Int
}
