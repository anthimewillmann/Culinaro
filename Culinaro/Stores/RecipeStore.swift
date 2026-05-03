import SwiftUI
import Combine

class RecipeStore: ObservableObject {
    @Published var recipes: [Recipe] = []
    
    func save(_ recipe: Recipe, editing original: Recipe?) {
        let cleaned = Recipe(
            id: original?.id ?? UUID(),
            title: recipe.title,
            ingredients: recipe.ingredients,
            steps: recipe.steps,
            isPinned: original?.isPinned ?? false,
            tipsEnabled: recipe.tipsEnabled,
            wasGenerated: recipe.wasGenerated, // ← fehlt
            createdAt: original?.createdAt ?? Date()
        )

        if let original, let index = recipes.firstIndex(where: { $0.id == original.id }) {
            recipes[index] = cleaned
        } else {
            recipes.append(cleaned)
        }
    }

    func delete(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
    }

    func togglePin(_ recipe: Recipe) {
        guard let index = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        recipes[index].isPinned.toggle()
    }
}
