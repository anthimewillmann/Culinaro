import CloudKit

extension Recipe {
    init?(record: CKRecord) {
        guard
            let id = UUID(uuidString: record.recordID.recordName),
            let title = record["title"] as? String,
            let steps = record["steps"] as? [String]
        else { return nil }
        self.init(
            id: id,
            title: title,
            ingredients: record["ingredients"] as? [String] ?? [],
            steps: steps,
            isPinned: (record["isPinned"] as? NSNumber)?.boolValue ?? false,
            tipsEnabled: (record["tipsEnabled"] as? NSNumber)?.boolValue ?? true,
            wasGenerated: (record["wasGenerated"] as? NSNumber)?.boolValue ?? false,
            createdAt: record["createdAt"] as? Date ?? .now
        )
    }

    var cloudRecord: CKRecord {
        let record = CKRecord(recordType: "Recipe", recordID: CKRecord.ID(recordName: id.uuidString))
        record["title"] = title as CKRecordValue
        record["ingredients"] = ingredients as CKRecordValue
        record["steps"] = steps as CKRecordValue
        record["isPinned"] = isPinned as CKRecordValue
        record["tipsEnabled"] = tipsEnabled as CKRecordValue
        record["wasGenerated"] = wasGenerated as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        return record
    }
}

extension Lesson {
    init?(record: CKRecord) {
        guard
            let id = UUID(uuidString: record.recordID.recordName),
            let title = record["title"] as? String,
            let steps = record["steps"] as? [String]
        else { return nil }
        let wasGenerated = (record["wasGenerated"] as? NSNumber)?.boolValue ?? false
        self.init(
            id: id,
            title: title,
            ingredients: record["ingredients"] as? [String] ?? [],
            steps: steps,
            isPinned: (record["isPinned"] as? NSNumber)?.boolValue ?? false,
            wasGenerated: wasGenerated,
            tipsEnabled: (record["tipsEnabled"] as? NSNumber)?.boolValue ?? !wasGenerated,
            createdAt: record["createdAt"] as? Date ?? .now
        )
    }

    var cloudRecord: CKRecord {
        let record = CKRecord(recordType: "Lesson", recordID: CKRecord.ID(recordName: id.uuidString))
        record["title"] = title as CKRecordValue
        record["ingredients"] = ingredients as CKRecordValue
        record["steps"] = steps as CKRecordValue
        record["isPinned"] = isPinned as CKRecordValue
        record["wasGenerated"] = wasGenerated as CKRecordValue
        record["tipsEnabled"] = tipsEnabled as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        return record
    }
}
