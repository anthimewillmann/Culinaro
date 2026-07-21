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
        Task { await upload(cleaned) }
    }

    func delete(_ lesson: Lesson) {
        lessons.removeAll { $0.id == lesson.id }
        persistCache()
        Task { try? await cloud.delete(id: lesson.id) }
    }

    func togglePin(_ lesson: Lesson) {
        guard let index = lessons.firstIndex(where: { $0.id == lesson.id }) else { return }
        lessons[index].isPinned.toggle()
        let updated = lessons[index]
        persistCache()
        Task { await upload(updated) }
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
        do { try await cloud.save(lesson); syncError = nil }
        catch { syncError = error.localizedDescription }
    }

    private func merge(local: [Lesson], remote: [Lesson]) -> [Lesson] {
        var values = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        remote.forEach { values[$0.id] = $0 }
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
