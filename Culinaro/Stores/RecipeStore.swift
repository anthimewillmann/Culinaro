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
    /// IDs deleted locally whose CloudKit deletion may not have propagated
    /// yet. Filtered out of every `merge(local:remote:)` so a `syncFromCloud()`
    /// (e.g. pull-to-refresh) racing ahead of the in-flight cloud delete can't
    /// resurrect an item the user just removed.
    private var pendingDeletionIDs: Set<UUID> = []
    /// IDs with a local edit whose upload may not have landed on the server
    /// yet. While pending, `merge(local:remote:)` keeps the LOCAL value for
    /// these IDs instead of the (possibly stale, pre-edit) remote one — same
    /// race as `pendingDeletionIDs`, but for edits/creates instead of deletes.
    private var pendingUploadIDs: Set<UUID> = []
    /// Laufende Upload-Tasks pro ID, damit `delete()` einen Upload, der zum
    /// Löschzeitpunkt noch nicht gesendet wurde, abbrechen kann — sonst
    /// könnte ein Upload, der nach dem `cloud.delete`-Aufruf beim Server
    /// ankommt, den gerade gelöschten Datensatz wiederauferstehen lassen.
    private var pendingUploadTasks: [UUID: Task<Void, Never>] = [:]

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
        pendingUploadIDs.insert(cleaned.id)
        pendingUploadTasks[cleaned.id] = Task {
            await upload(cleaned)
            pendingUploadIDs.remove(cleaned.id)
            pendingUploadTasks.removeValue(forKey: cleaned.id)
        }
    }

    func delete(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
        pendingDeletionIDs.insert(recipe.id)
        pendingUploadTasks[recipe.id]?.cancel()
        persistCache()
        Task {
            try? await cloud.delete(id: recipe.id)
            pendingDeletionIDs.remove(recipe.id)
        }
    }

    func togglePin(_ recipe: Recipe) {
        guard let index = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        recipes[index].isPinned.toggle()
        let updated = recipes[index]
        persistCache()
        pendingUploadIDs.insert(updated.id)
        pendingUploadTasks[updated.id] = Task {
            await upload(updated)
            pendingUploadIDs.remove(updated.id)
            pendingUploadTasks.removeValue(forKey: updated.id)
        }
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
        guard !Task.isCancelled else { return }
        do { try await cloud.save(recipe); syncError = nil }
        catch { syncError = error.localizedDescription }
    }

    private func merge(local: [Recipe], remote: [Recipe]) -> [Recipe] {
        var values = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for item in remote where !pendingUploadIDs.contains(item.id) {
            values[item.id] = item
        }
        pendingDeletionIDs.forEach { values.removeValue(forKey: $0) }
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
