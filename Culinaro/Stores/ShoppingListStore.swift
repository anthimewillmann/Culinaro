import Foundation
import Combine

@MainActor
final class ShoppingListStore: ObservableObject {
    @Published private(set) var items: [ShoppingListItem] = []
    @Published private(set) var syncError: String?
    /// Eigenständiges, append-only Protokoll aller Abhak-Vorgänge — bewusst
    /// unabhängig vom Lebenszyklus der Einträge in `items`, damit "Erledigte
    /// löschen" (oder das spätere Löschen eines einzelnen Eintrags) den
    /// Verlauf nicht mit-löscht. Nur lokal persistiert (kein CloudKit-Sync):
    /// der Verlauf ist kurzlebig (History zeigt nur die letzte Stunde) und
    /// geräteübergreifende Konsistenz hat hier keinen praktischen Nutzen.
    @Published private(set) var checkedHistory: [ShoppingHistoryEntry] = []

    private let storageKey = "culinaro.shoppingList.items"
    private let historyStorageKey = "culinaro.shoppingList.checkedHistory"
    /// Deutlich großzügiger als das 1-Stunden-Fenster, das die History-Ansicht
    /// anzeigt — verhindert unbegrenztes Wachstum, ohne dass das Aufräumen
    /// selbst zeitkritisch wäre.
    private let historyRetention: TimeInterval = 24 * 3600
    private let cloud: CloudKitManager
    private let recipeLookup: @MainActor (UUID) -> Recipe?
    private var pendingDeletionIDs: Set<UUID> = []
    private var pendingUploadIDs: Set<UUID> = []
    private var pendingUploadTasks: [UUID: Task<Void, Never>] = [:]

    var plannedCalories: Int {
        let recipeIDs = Set(items.compactMap { $0.sourceRecipeID })
        return recipeIDs.reduce(0) { total, recipeID in
            total + (recipeLookup(recipeID)?.nutrition?.calories ?? 0)
        }
    }

    init(cloud: CloudKitManager? = nil, recipeLookup: @escaping @MainActor (UUID) -> Recipe? = { _ in nil }) {
        self.cloud = cloud ?? .shared
        self.recipeLookup = recipeLookup
        loadCache()
        loadHistoryCache()
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
        pendingUploadIDs.insert(item.id)
        pendingUploadTasks[item.id] = Task {
            await upload(item)
            pendingUploadIDs.remove(item.id)
            pendingUploadTasks.removeValue(forKey: item.id)
        }
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
        let checkedAt = items[index].isChecked ? Date() : nil
        items[index].checkedAt = checkedAt
        let updated = items[index]
        persistCache()
        pendingUploadIDs.insert(updated.id)
        pendingUploadTasks[updated.id] = Task {
            await upload(updated)
            pendingUploadIDs.remove(updated.id)
            pendingUploadTasks.removeValue(forKey: updated.id)
        }

        if let checkedAt {
            checkedHistory.append(ShoppingHistoryEntry(
                itemName: updated.name,
                quantity: updated.quantity,
                sourceRecipeTitle: updated.sourceRecipeTitle,
                checkedAt: checkedAt
            ))
            pruneHistory()
            persistHistoryCache()
        }
    }

    func delete(_ item: ShoppingListItem) {
        items.removeAll { $0.id == item.id }
        pendingDeletionIDs.insert(item.id)
        pendingUploadTasks[item.id]?.cancel()
        persistCache()
        Task {
            try? await cloud.delete(id: item.id)
            pendingDeletionIDs.remove(item.id)
        }
    }

    func deleteAllChecked() {
        let checked = items.filter(\.isChecked)
        guard !checked.isEmpty else { return }
        items.removeAll { $0.isChecked }
        let checkedIDs = Set(checked.map(\.id))
        pendingDeletionIDs.formUnion(checkedIDs)
        checkedIDs.forEach { pendingUploadTasks[$0]?.cancel() }
        persistCache()
        Task {
            for item in checked {
                try? await cloud.delete(id: item.id)
            }
            pendingDeletionIDs.subtract(checkedIDs)
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
        let changedIDs = Set(changedItems.map(\.id))
        pendingUploadIDs.formUnion(changedIDs)
        Task {
            for item in changedItems {
                await upload(item)
            }
            pendingUploadIDs.subtract(changedIDs)
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
        let newIDs = Set(newItems.map(\.id))
        pendingUploadIDs.formUnion(newIDs)
        Task {
            for item in newItems {
                await upload(item)
            }
            pendingUploadIDs.subtract(newIDs)
        }
    }

    private func upload(_ item: ShoppingListItem) async {
        guard !Task.isCancelled else { return }
        do { try await cloud.save(item); syncError = nil }
        catch { syncError = error.localizedDescription }
    }

    private func merge(local: [ShoppingListItem], remote: [ShoppingListItem]) -> [ShoppingListItem] {
        var values = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for item in remote where !pendingUploadIDs.contains(item.id) {
            values[item.id] = item
        }
        pendingDeletionIDs.forEach { values.removeValue(forKey: $0) }
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

    private func pruneHistory() {
        let cutoff = Date().addingTimeInterval(-historyRetention)
        checkedHistory.removeAll { $0.checkedAt < cutoff }
    }

    private func persistHistoryCache() {
        guard let data = try? JSONEncoder().encode(checkedHistory) else { return }
        UserDefaults.standard.set(data, forKey: historyStorageKey)
    }

    private func loadHistoryCache() {
        guard let data = UserDefaults.standard.data(forKey: historyStorageKey),
              let decoded = try? JSONDecoder().decode([ShoppingHistoryEntry].self, from: data) else { return }
        checkedHistory = decoded
        pruneHistory()
    }
}

/// Ein einzelner Abhak-Vorgang, unabhängig vom zugehörigen `ShoppingListItem`
/// (das nach dem Abhaken gelöscht worden sein kann).
struct ShoppingHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let itemName: String
    let quantity: String?
    let sourceRecipeTitle: String?
    let checkedAt: Date

    init(id: UUID = UUID(), itemName: String, quantity: String?, sourceRecipeTitle: String?, checkedAt: Date) {
        self.id = id
        self.itemName = itemName
        self.quantity = quantity
        self.sourceRecipeTitle = sourceRecipeTitle
        self.checkedAt = checkedAt
    }
}
