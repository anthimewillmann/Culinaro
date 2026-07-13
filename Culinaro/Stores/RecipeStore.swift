import Foundation
import Combine

@MainActor
final class RecipeStore: ObservableObject {
    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var totalCreatedRecipes: Int = 0
    @Published private(set) var syncError: String?

    private let storageKey = "culinaro.recipes"
    private let totalCreatedKey = "culinaro.recipes.totalCreated"
    private let cloud: CloudKitManager

    init(cloud: CloudKitManager? = nil) {
        self.cloud = cloud ?? .shared
        loadCache()
        loadTotalCreatedCount()
        Task { await syncFromCloud() }
    }

    func save(_ recipe: Recipe, editing original: Recipe?) {
        let cleaned = Recipe(
            id: original?.id ?? recipe.id,
            title: recipe.title.trimmingCharacters(in: .whitespacesAndNewlines),
            ingredients: recipe.ingredients,
            steps: recipe.steps,
            isPinned: original?.isPinned ?? recipe.isPinned,
            tipsEnabled: recipe.tipsEnabled,
            wasGenerated: recipe.wasGenerated,
            nutrition: recipe.nutrition,
            createdAt: original?.createdAt ?? recipe.createdAt
        )
        if let index = recipes.firstIndex(where: { $0.id == cleaned.id }) {
            recipes[index] = cleaned
        } else {
            recipes.append(cleaned)
            totalCreatedRecipes += 1
            persistTotalCreatedCount()
        }
        persistCache()
        Task { await upload(cleaned) }
    }

    func delete(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
        persistCache()
        Task { try? await cloud.delete(id: recipe.id) }
    }

    func togglePin(_ recipe: Recipe) {
        guard let index = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        recipes[index].isPinned.toggle()
        let updated = recipes[index]
        persistCache()
        Task { await upload(updated) }
    }

    func syncFromCloud() async {
        do {
            let remote = try await cloud.fetchRecipes()
            recipes = merge(local: recipes, remote: remote)
            updateTotalCreatedCountIfNeeded(minimum: recipes.count)
            persistCache()
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func upload(_ recipe: Recipe) async {
        do { try await cloud.save(recipe); syncError = nil }
        catch { syncError = error.localizedDescription }
    }

    private func merge(local: [Recipe], remote: [Recipe]) -> [Recipe] {
        var values = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        remote.forEach { values[$0.id] = $0 }
        return Array(values.values)
    }

    private func persistCache() {
        guard let data = try? JSONEncoder().encode(recipes) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Recipe].self, from: data) else { return }
        recipes = decoded
    }

    private func loadTotalCreatedCount() {
        if UserDefaults.standard.object(forKey: totalCreatedKey) == nil {
            totalCreatedRecipes = recipes.count
        } else {
            totalCreatedRecipes = UserDefaults.standard.integer(forKey: totalCreatedKey)
            updateTotalCreatedCountIfNeeded(minimum: recipes.count)
        }
        persistTotalCreatedCount()
    }

    private func updateTotalCreatedCountIfNeeded(minimum: Int) {
        guard totalCreatedRecipes < minimum else { return }
        totalCreatedRecipes = minimum
        persistTotalCreatedCount()
    }

    private func persistTotalCreatedCount() {
        UserDefaults.standard.set(totalCreatedRecipes, forKey: totalCreatedKey)
    }
}
