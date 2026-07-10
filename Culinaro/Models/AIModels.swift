import FoundationModels

// MARK: - ParsedRecipe

/// A structured output model for Apple Intelligence (FoundationModels).
/// Used when generating a recipe from a title or scanning one from an image.
@Generable
struct ParsedRecipe {
    @Guide(description: "The title of the recipe")
    var title: String

    @Guide(description: "List of ingredients")
    var ingredients: [String]

    @Guide(description: "Preparation steps")
    var steps: [String]
}

// MARK: - ParsedLesson

/// A structured output model for Apple Intelligence (FoundationModels).
/// Used when generating a cooking lesson from a title or scanning one from an image.
@Generable
struct ParsedLesson {
    @Guide(description: "The title of the cooking lesson")
    var title: String

    @Guide(description: "Step-by-step teaching instructions for the lesson")
    var steps: [String]
}

// MARK: - CookingTip

/// A structured output model for Apple Intelligence (FoundationModels).
/// Holds a single short cooking tip generated for a recipe step.
@Generable
struct CookingTip {
    @Guide(description: "A short, helpful cooking tip (max. 15 words)")
    var tip: String
}

// MARK: - Categorization

/// A structured output model for Apple Intelligence (FoundationModels).
/// One category assignment for a single item, matched back by its id.
@Generable
struct CategorizedItem {
    @Guide(description: "The id, copied exactly as given, unmodified")
    var id: String

    @Guide(description: "A short, sensible category name for this item (one or two words), in the same language as the title")
    var category: String
}

/// A structured output model for Apple Intelligence (FoundationModels).
/// Holds the category assignment for every item in a batch.
@Generable
struct CategorizationResult {
    @Guide(description: "One entry per given item")
    var items: [CategorizedItem]
}
