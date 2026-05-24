import Foundation

/// Represents a single recipe with a title, ingredients, steps,
/// and metadata such as pin state, tip preference, and creation date.
struct Recipe: Identifiable, Codable {
    let id: UUID
    let title: String
    let ingredients: [String]
    let steps: [String]
    var isPinned: Bool
    var tipsEnabled: Bool
    var wasGenerated: Bool
    let createdAt: Date
 
    init(
        id: UUID = UUID(),
        title: String,
        ingredients: [String] = [],
        steps: [String],
        isPinned: Bool = false,
        tipsEnabled: Bool = true,
        wasGenerated: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.ingredients = ingredients
        self.steps = steps
        self.isPinned = isPinned
        self.tipsEnabled = tipsEnabled
        self.wasGenerated = wasGenerated
        self.createdAt = createdAt
    }
}
