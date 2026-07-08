import CloudKit

final class CloudKitManager {
    static let shared = CloudKitManager()
    private let database: CKDatabase

    init(container: CKContainer = .default()) {
        database = container.privateCloudDatabase
    }

    func fetchRecipes() async throws -> [Recipe] {
        try await fetch(recordType: "Recipe").compactMap(Recipe.init(record:))
    }

    func fetchLessons() async throws -> [Lesson] {
        try await fetch(recordType: "Lesson").compactMap(Lesson.init(record:))
    }

    func save(_ recipe: Recipe) async throws { _ = try await database.save(recipe.cloudRecord) }
    func save(_ lesson: Lesson) async throws { _ = try await database.save(lesson.cloudRecord) }

    func delete(id: UUID) async throws {
        _ = try await database.deleteRecord(withID: CKRecord.ID(recordName: id.uuidString))
    }

    private func fetch(recordType: String) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        var records: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        repeat {
            let result: (matchResults: [(CKRecord.ID, Result<CKRecord, any Error>)], queryCursor: CKQueryOperation.Cursor?)
            if let cursor {
                result = try await database.records(continuingMatchFrom: cursor)
            } else {
                result = try await database.records(matching: query)
            }
            records.append(contentsOf: result.matchResults.compactMap { try? $0.1.get() })
            cursor = result.queryCursor
        } while cursor != nil
        return records
    }
}
