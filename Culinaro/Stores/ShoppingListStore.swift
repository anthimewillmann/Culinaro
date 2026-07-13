import Foundation
import Combine

@MainActor
final class ShoppingListStore: ObservableObject {
    @Published private(set) var items: [ShoppingListItem] = []
    @Published private(set) var syncError: String?

    private let storageKey = "culinaro.shoppingList.items"
    private let cloud: CloudKitManager
    private let recipeLookup: (UUID) -> Recipe?

    var plannedCalories: Int {
        let recipeIDs = Set(items.compactMap { $0.sourceRecipeID })
        return recipeIDs.reduce(0) { total, recipeID in
            total + (recipeLookup(recipeID)?.nutrition?.calories ?? 0)
        }
    }

    init(cloud: CloudKitManager? = nil, recipeLookup: @escaping (UUID) -> Recipe? = { _ in nil }) {
        self.cloud = cloud ?? .shared
        self.recipeLookup = recipeLookup
        loadCache()
        Task { await syncFromCloud() }
    }

    func add(name: String, quantity: String? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let trimmedQuantity = quantity?.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = ShoppingListItem(
            name: trimmedName,
            quantity: trimmedQuantity?.isEmpty == false ? trimmedQuantity : nil
        )
        items.append(item)
        persistCache()
        Task { await upload(item) }
    }

    func addIngredients(from recipe: Recipe) {
        addIngredients(recipe.ingredients, sourceID: recipe.id, sourceTitle: recipe.title)
    }

    func addIngredients(from lesson: Lesson) {
        addIngredients(lesson.ingredients, sourceID: lesson.id, sourceTitle: lesson.title)
    }

    func toggleChecked(_ item: ShoppingListItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isChecked.toggle()
        let updated = items[index]
        persistCache()
        Task { await upload(updated) }
    }

    func delete(_ item: ShoppingListItem) {
        items.removeAll { $0.id == item.id }
        persistCache()
        Task { try? await cloud.delete(id: item.id) }
    }

    func deleteAllChecked() {
        let checked = items.filter(\.isChecked)
        guard !checked.isEmpty else { return }
        items.removeAll { $0.isChecked }
        persistCache()
        Task {
            for item in checked {
                try? await cloud.delete(id: item.id)
            }
        }
    }

    func applyCategories(_ categoriesByID: [UUID: String]) {
        var changedItems: [ShoppingListItem] = []
        for index in items.indices {
            guard let category = categoriesByID[items[index].id], items[index].category != category else { continue }
            items[index].category = category
            changedItems.append(items[index])
        }
        guard !changedItems.isEmpty else { return }
        persistCache()
        Task {
            for item in changedItems {
                await upload(item)
            }
        }
    }

    func syncFromCloud() async {
        do {
            let remote = try await cloud.fetchShoppingListItems()
            items = merge(local: items, remote: remote)
            persistCache()
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func addIngredients(_ ingredients: [String], sourceID: UUID, sourceTitle: String) {
        let newItems = ingredients
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map {
                ShoppingListItem(
                    name: $0,
                    sourceRecipeID: sourceID,
                    sourceRecipeTitle: sourceTitle
                )
            }

        guard !newItems.isEmpty else { return }
        items.append(contentsOf: newItems)
        persistCache()
        Task {
            for item in newItems {
                await upload(item)
            }
        }
    }

    private func upload(_ item: ShoppingListItem) async {
        do { try await cloud.save(item); syncError = nil }
        catch { syncError = error.localizedDescription }
    }

    private func merge(local: [ShoppingListItem], remote: [ShoppingListItem]) -> [ShoppingListItem] {
        var values = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        remote.forEach { values[$0.id] = $0 }
        return Array(values.values)
    }

    private func persistCache() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ShoppingListItem].self, from: data) else { return }
        items = decoded
    }
}
