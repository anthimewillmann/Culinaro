import Foundation

/// A uniquely identified wrapper around a `String`, used as a row model
/// in dynamic text field lists (ingredients and steps in `AddRecipeView`).
struct TextRow: Identifiable, Equatable {
    let id: UUID
    var text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}
