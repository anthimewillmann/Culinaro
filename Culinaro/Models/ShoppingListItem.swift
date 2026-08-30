import Foundation

struct ShoppingListItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var quantity: String?
    var isChecked: Bool
    var checkedAt: Date?
    var category: String?
    var sourceRecipeID: UUID?
    var sourceRecipeTitle: String?
    let createdAt: Date
    /// Zeitpunkt, an dem der Eintrag zuletzt abgehakt wurde — `nil`, solange
    /// er nicht abgehakt ist. Dient der "Verlauf"-Ansicht, die alle in der
    /// letzten Stunde abgehakten Zutaten anzeigt.
    var checkedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: String? = nil,
        isChecked: Bool = false,
        checkedAt: Date? = nil,
        category: String? = nil,
        sourceRecipeID: UUID? = nil,
        sourceRecipeTitle: String? = nil,
        createdAt: Date = Date(),
        checkedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.isChecked = isChecked
        self.checkedAt = checkedAt
        self.category = category
        self.sourceRecipeID = sourceRecipeID
        self.sourceRecipeTitle = sourceRecipeTitle
        self.createdAt = createdAt
        self.checkedAt = checkedAt
    }
}
