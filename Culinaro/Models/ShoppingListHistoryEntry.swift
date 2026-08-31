import Foundation

struct ShoppingListHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var quantity: String?
    var sourceRecipeTitle: String?
    let checkedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        quantity: String? = nil,
        sourceRecipeTitle: String? = nil,
        checkedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.sourceRecipeTitle = sourceRecipeTitle
        self.checkedAt = checkedAt
    }
}
