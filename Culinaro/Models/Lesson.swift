import Foundation

struct Lesson: Cookable, Codable, Equatable {
    let id: UUID
    let title: String
    let ingredients: [String]
    let steps: [String]
    var isPinned: Bool
    var wasGenerated: Bool
    var tipsEnabled: Bool
    var nutrition: NutritionInfo?
    let createdAt: Date
    var completionKind: CompletionKind { .lesson }

    init(
        id: UUID = UUID(),
        title: String,
        ingredients: [String] = [],
        steps: [String],
        isPinned: Bool = false,
        wasGenerated: Bool = false,
        tipsEnabled: Bool = true,
        nutrition: NutritionInfo? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.ingredients = ingredients
        self.steps = steps
        self.isPinned = isPinned
        self.wasGenerated = wasGenerated
        self.tipsEnabled = tipsEnabled
        self.nutrition = nutrition
        self.createdAt = createdAt
    }
}
