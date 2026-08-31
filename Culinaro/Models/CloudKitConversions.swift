import CloudKit

extension Recipe {
    init?(record: CKRecord) {
        guard
            let id = UUID(uuidString: record.recordID.recordName),
            let title = record["title"] as? String,
            let steps = record["steps"] as? [String]
        else { return nil }
        let nutrition = Recipe.nutrition(from: record)
        self.init(
            id: id,
            title: title,
            ingredients: record["ingredients"] as? [String] ?? [],
            steps: steps,
            isPinned: (record["isPinned"] as? NSNumber)?.boolValue ?? false,
            tipsEnabled: (record["tipsEnabled"] as? NSNumber)?.boolValue ?? true,
            wasGenerated: (record["wasGenerated"] as? NSNumber)?.boolValue ?? false,
            nutrition: nutrition,
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
        if let nutrition {
            record["nutritionCalories"] = nutrition.calories as CKRecordValue?
            record["nutritionProtein"] = nutrition.proteinGrams as CKRecordValue?
            record["nutritionCarbs"] = nutrition.carbsGrams as CKRecordValue?
            record["nutritionFat"] = nutrition.fatGrams as CKRecordValue?
            record["nutritionServings"] = nutrition.servings as CKRecordValue
        }
        return record
    }

    private static func nutrition(from record: CKRecord) -> NutritionInfo? {
        let calories = record["nutritionCalories"] as? Int
        let protein = record["nutritionProtein"] as? Double
        let carbs = record["nutritionCarbs"] as? Double
        let fat = record["nutritionFat"] as? Double
        let servings = record["nutritionServings"] as? Int ?? 1
        guard calories != nil || protein != nil || carbs != nil || fat != nil else { return nil }
        return NutritionInfo(calories: calories, proteinGrams: protein, carbsGrams: carbs, fatGrams: fat, servings: servings)
    }
}

extension LoggedMeal {
    init?(record: CKRecord) {
        guard
            let id = UUID(uuidString: record.recordID.recordName),
            let recipeIDString = record["recipeID"] as? String,
            let recipeID = UUID(uuidString: recipeIDString),
            let recipeTitle = record["recipeTitle"] as? String,
            let servingsEaten = record["servingsEaten"] as? Double,
            let calories = record["calories"] as? Int,
            let loggedAt = record["loggedAt"] as? Date
        else { return nil }

        self.init(
            id: id,
            recipeID: recipeID,
            recipeTitle: recipeTitle,
            servingsEaten: servingsEaten,
            calories: calories,
            proteinGrams: record["proteinGrams"] as? Double ?? 0,
            carbsGrams: record["carbsGrams"] as? Double ?? 0,
            fatGrams: record["fatGrams"] as? Double ?? 0,
            loggedAt: loggedAt
        )
    }

    var cloudRecord: CKRecord {
        let record = CKRecord(recordType: "LoggedMeal", recordID: CKRecord.ID(recordName: id.uuidString))
        record["recipeID"] = recipeID.uuidString as CKRecordValue
        record["recipeTitle"] = recipeTitle as CKRecordValue
        record["servingsEaten"] = servingsEaten as CKRecordValue
        record["calories"] = calories as CKRecordValue
        record["proteinGrams"] = proteinGrams as CKRecordValue
        record["carbsGrams"] = carbsGrams as CKRecordValue
        record["fatGrams"] = fatGrams as CKRecordValue
        record["loggedAt"] = loggedAt as CKRecordValue
        return record
    }
}

extension ShoppingListItem {
    init?(record: CKRecord) {
        guard
            let id = UUID(uuidString: record.recordID.recordName),
            let name = record["name"] as? String,
            let isChecked = (record["isChecked"] as? NSNumber)?.boolValue,
            let createdAt = record["createdAt"] as? Date
        else { return nil }

        let sourceRecipeID = (record["sourceRecipeID"] as? String).flatMap(UUID.init(uuidString:))
        self.init(
            id: id,
            name: name,
            quantity: record["quantity"] as? String,
            isChecked: isChecked,
            category: record["category"] as? String,
            sourceRecipeID: sourceRecipeID,
            sourceRecipeTitle: record["sourceRecipeTitle"] as? String,
            createdAt: createdAt,
            checkedAt: record["checkedAt"] as? Date
        )
    }

    var cloudRecord: CKRecord {
        let record = CKRecord(recordType: "ShoppingListItem", recordID: CKRecord.ID(recordName: id.uuidString))
        record["name"] = name as CKRecordValue
        record["quantity"] = quantity as CKRecordValue?
        record["isChecked"] = isChecked as CKRecordValue
        record["checkedAt"] = checkedAt as CKRecordValue?
        record["category"] = category as CKRecordValue?
        record["sourceRecipeID"] = sourceRecipeID?.uuidString as CKRecordValue?
        record["sourceRecipeTitle"] = sourceRecipeTitle as CKRecordValue?
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
        let nutrition = Lesson.nutrition(from: record)
        self.init(
            id: id,
            title: title,
            ingredients: record["ingredients"] as? [String] ?? [],
            steps: steps,
            isPinned: (record["isPinned"] as? NSNumber)?.boolValue ?? false,
            wasGenerated: wasGenerated,
            tipsEnabled: (record["tipsEnabled"] as? NSNumber)?.boolValue ?? !wasGenerated,
            nutrition: nutrition,
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
        if let nutrition {
            record["nutritionCalories"] = nutrition.calories as CKRecordValue?
            record["nutritionProtein"] = nutrition.proteinGrams as CKRecordValue?
            record["nutritionCarbs"] = nutrition.carbsGrams as CKRecordValue?
            record["nutritionFat"] = nutrition.fatGrams as CKRecordValue?
            record["nutritionServings"] = nutrition.servings as CKRecordValue
        }
        return record
    }

    private static func nutrition(from record: CKRecord) -> NutritionInfo? {
        let calories = record["nutritionCalories"] as? Int
        let protein = record["nutritionProtein"] as? Double
        let carbs = record["nutritionCarbs"] as? Double
        let fat = record["nutritionFat"] as? Double
        let servings = record["nutritionServings"] as? Int ?? 1
        guard calories != nil || protein != nil || carbs != nil || fat != nil else { return nil }
        return NutritionInfo(calories: calories, proteinGrams: protein, carbsGrams: carbs, fatGrams: fat, servings: servings)
    }
}
