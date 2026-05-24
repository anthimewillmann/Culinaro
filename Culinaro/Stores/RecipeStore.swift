import SwiftUI
import Combine

/// Observable store that manages the in-memory list of recipes.
/// Provides save, delete, and pin-toggle operations.
///
/// - Note: Recipes are persisted across app launches using UserDefaults + JSONEncoder.
class RecipeStore: ObservableObject {
    @Published var recipes: [Recipe] = [] {
        didSet { persistRecipes() }
    }

    private let storageKey = "culinaro.recipes"

    init() {
        loadRecipes()
    }

    // MARK: - Persistence

    /// Encodes and writes the current recipe list to UserDefaults.
    private func persistRecipes() {
        if let encoded = try? JSONEncoder().encode(recipes) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    /// Loads and decodes the recipe list from UserDefaults on app launch.
    private func loadRecipes() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Recipe].self, from: data)
        else { return }
        recipes = decoded
    }

    // MARK: - Operations

    /// Saves a new recipe or updates an existing one.
    /// - Parameters:
    ///   - recipe: The recipe to save.
    ///   - original: The existing recipe to replace, or `nil` to append a new one.
    func save(_ recipe: Recipe, editing original: Recipe?) {
        let cleaned = Recipe(
            id: original?.id ?? UUID(),
            title: recipe.title,
            ingredients: recipe.ingredients,
            steps: recipe.steps,
            isPinned: original?.isPinned ?? false,
            tipsEnabled: recipe.tipsEnabled,
            wasGenerated: recipe.wasGenerated,
            createdAt: original?.createdAt ?? Date()
        )
        if let original, let index = recipes.firstIndex(where: { $0.id == original.id }) {
            recipes[index] = cleaned
        } else {
            recipes.append(cleaned)
        }
    }

    /// Removes a recipe from the list.
    func delete(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
    }

    /// Toggles the pinned state of a recipe.
    func togglePin(_ recipe: Recipe) {
        guard let index = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        recipes[index].isPinned.toggle()
    }
}
