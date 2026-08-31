import Foundation
import Combine

@MainActor
final class LessonStore: ObservableObject {
    @Published private(set) var lessons: [Lesson] = []
    @Published private(set) var totalCreatedLessons: Int = 0
    @Published private(set) var syncError: String?

    private let storageKey = "culinaro.lessons"
    private let totalCreatedKey = "culinaro.lessons.totalCreated"
    private let cloud: CloudKitManager
    /// IDs deleted locally whose CloudKit deletion may not have propagated
    /// yet — siehe RecipeStore für die ausführliche Begründung.
    private var pendingDeletionIDs: Set<UUID> = []
    /// IDs mit einer lokalen Änderung, deren Upload noch nicht bestätigt ist
    /// — siehe RecipeStore für die ausführliche Begründung.
    private var pendingUploadIDs: Set<UUID> = []
    /// Laufende Upload-Tasks pro ID — siehe RecipeStore für die ausführliche
    /// Begründung (verhindert, dass ein Upload einen gelöschten Datensatz
    /// wiederauferstehen lässt).
    private var pendingUploadTasks: [UUID: Task<Void, Never>] = [:]

    init(cloud: CloudKitManager? = nil) {
        self.cloud = cloud ?? .shared
        loadCache()
        loadTotalCreatedCount()
        Task { await syncFromCloud() }
    }

    func save(_ lesson: Lesson, editing original: Lesson?) {
        let cleaned = Lesson(
            id: original?.id ?? lesson.id,
            title: lesson.title.trimmingCharacters(in: .whitespacesAndNewlines),
            ingredients: lesson.ingredients,
            steps: lesson.steps,
            isPinned: original?.isPinned ?? lesson.isPinned,
            wasGenerated: lesson.wasGenerated,
            tipsEnabled: lesson.tipsEnabled,
            nutrition: lesson.nutrition,
            createdAt: original?.createdAt ?? lesson.createdAt
        )
        if let index = lessons.firstIndex(where: { $0.id == cleaned.id }) {
            lessons[index] = cleaned
        } else {
            lessons.append(cleaned)
            totalCreatedLessons += 1
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

    func delete(_ lesson: Lesson) {
        lessons.removeAll { $0.id == lesson.id }
        pendingDeletionIDs.insert(lesson.id)
        pendingUploadTasks[lesson.id]?.cancel()
        persistCache()
        Task {
            try? await cloud.delete(id: lesson.id)
            pendingDeletionIDs.remove(lesson.id)
        }
    }

    func togglePin(_ lesson: Lesson) {
        guard let index = lessons.firstIndex(where: { $0.id == lesson.id }) else { return }
        lessons[index].isPinned.toggle()
        let updated = lessons[index]
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
            let remote = try await cloud.fetchLessons()
            lessons = merge(local: lessons, remote: remote)
            updateTotalCreatedCountIfNeeded(minimum: lessons.count)
            persistCache()
            syncError = nil
        } catch { syncError = error.localizedDescription }
    }

    private func upload(_ lesson: Lesson) async {
        guard !Task.isCancelled else { return }
        do { try await cloud.save(lesson); syncError = nil }
        catch { syncError = error.localizedDescription }
    }

    private func merge(local: [Lesson], remote: [Lesson]) -> [Lesson] {
        var values = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for item in remote where !pendingUploadIDs.contains(item.id) {
            values[item.id] = item
        }
        pendingDeletionIDs.forEach { values.removeValue(forKey: $0) }
        return Array(values.values)
    }

    private func persistCache() {
        guard let data = try? JSONEncoder().encode(lessons) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Lesson].self, from: data) else { return }
        lessons = decoded
    }

    private func loadTotalCreatedCount() {
        if UserDefaults.standard.object(forKey: totalCreatedKey) == nil {
            totalCreatedLessons = lessons.count
        } else {
            totalCreatedLessons = UserDefaults.standard.integer(forKey: totalCreatedKey)
            updateTotalCreatedCountIfNeeded(minimum: lessons.count)
        }
        persistTotalCreatedCount()
    }

    private func updateTotalCreatedCountIfNeeded(minimum: Int) {
        guard totalCreatedLessons < minimum else { return }
        totalCreatedLessons = minimum
        persistTotalCreatedCount()
    }

    private func persistTotalCreatedCount() {
        UserDefaults.standard.set(totalCreatedLessons, forKey: totalCreatedKey)
    }
}
