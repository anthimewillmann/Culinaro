import Foundation

struct Recipe: Identifiable {
    let id: UUID
    let title: String
    let ingredients: [String]
    let steps: [String]
    var isPinned: Bool = false
    var tipsEnabled: Bool = true
    let createdAt: Date

    init(id: UUID = UUID(), title: String, ingredients: [String] = [], steps: [String], isPinned: Bool = false, tipsEnabled: Bool = true, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.ingredients = ingredients
        self.steps = steps
        self.isPinned = isPinned
        self.tipsEnabled = tipsEnabled
        self.createdAt = createdAt
    }
}
