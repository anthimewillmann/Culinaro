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

// MARK: - CookingTip

/// A structured output model for Apple Intelligence (FoundationModels).
/// Holds a single short cooking tip generated for a recipe step.
@Generable
struct CookingTip {
    @Guide(description: "A short, helpful cooking tip (max. 15 words)")
    var tip: String
}
