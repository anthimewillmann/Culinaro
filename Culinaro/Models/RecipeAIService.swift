import Foundation
import FoundationModels
import Vision
import UIKit

/// Service that interfaces with Apple Intelligence via FoundationModels.
///
/// Provides capabilities for both recipes and lessons:
/// - `generate(from:allergies:)` – Creates a full recipe from a title string.
/// - `scan(image:)` – Extracts a recipe from a photo using Vision + LLM.
/// - `cookingTip(for:)` – Generates a short tip for a single recipe step.
/// - `generateLesson(from:)` / `scanLesson(image:)` – Same idea, for Duolingo-style lessons.
/// - `categorize(_:contextHint:)` – Groups existing recipes/lessons into sensible
///   categories (e.g. Frühstück/Mittagessen/Abendessen, or Backen/Kochen) that the
///   model itself decides, based on the current set of titles.
@Observable
final class RecipeAIService {

    /// Returns a strict language instruction based on the device's preferred language.
    private var languageInstruction: String {
        let languageIdentifier = Locale.preferredLanguages.first ?? "en"
        return "Respond only in the device's preferred language '\(languageIdentifier)'. All user-visible text, especially category names, must use this language regardless of the language used in the input or context. "
    }

    // MARK: - Recipes

    /// Generates a complete recipe from a plain-text title prompt.
    /// - Parameters:
    ///   - prompt: The recipe idea or dish name.
    ///   - allergies: Optional comma/semicolon-separated allergies or intolerances
    ///     to avoid. Pass the user's `StatsStore.allergies` value here.
    /// - Returns: A `ParsedRecipe` with title, ingredients, and steps.
    func generate(from prompt: String, allergies: String = "") async throws -> ParsedRecipe {
        let session = LanguageModelSession()
        var fullPrompt = "\(languageInstruction)Create a complete recipe for: \(prompt). Respond structured with title, ingredients and steps."

        let trimmedAllergies = allergies.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAllergies.isEmpty {
            fullPrompt += " Important: the person has the following allergies or intolerances, the recipe must not use any ingredient related to these: \(trimmedAllergies)."
        }

        let response = try await session.respond(to: fullPrompt, generating: ParsedRecipe.self)
        return response.content
    }

    /// Scans an image and extracts a recipe using OCR and the language model.
    /// - Throws: `ScanError.noTextFound` if no text could be recognised.
    func scan(image: UIImage) async throws -> ParsedRecipe {
        let session = LanguageModelSession()
        let rawText = try await extractText(from: image)
        guard !rawText.isEmpty else { throw ScanError.noTextFound }
        let fullPrompt = "\(languageInstruction)Extract recipe from: \(rawText)"
        let response = try await session.respond(to: fullPrompt, generating: ParsedRecipe.self)
        return response.content
    }

    /// Scans an image and extracts shopping list items using OCR and the language model.
    /// Quantities stay attached to the item text so the existing shopping-list editor can refine them.
    func scanShoppingList(image: UIImage) async throws -> ParsedShoppingList {
        let session = LanguageModelSession()
        let rawText = try await extractText(from: image)
        guard !rawText.isEmpty else { throw ScanError.noTextFound }
        let fullPrompt = "\(languageInstruction)Extract only the shopping list items or ingredients from this text. Keep visible quantities with the item, ignore notes, prices, totals and preparation instructions: \(rawText)"
        let response = try await session.respond(to: fullPrompt, generating: ParsedShoppingList.self)
        return response.content
    }

    /// Estimates nutritional values per serving from a recipe title and ingredients.
    func estimateNutrition(title: String, ingredients: [String], steps: [String] = []) async throws -> NutritionEstimate {
        let session = LanguageModelSession()
        let ingredientListing = ingredients.map { "- \($0)" }.joined(separator: "\n")
        let stepListing = steps.map { "- \($0)" }.joined(separator: "\n")
        let fullPrompt = """
        \(languageInstruction)Estimate approximate nutrition for this recipe or cooking lesson. This is only an estimate, not an exact medical or dietetic statement. Return all nutrition fields: calories, protein, carbohydrates and fat, plus the assumed number of servings. If ingredients are missing, infer a reasonable estimate from the title and preparation steps.
        Title: \(title)
        Ingredients:
        \(ingredientListing)
        Steps:
        \(stepListing)
        """
        let response = try await session.respond(to: fullPrompt, generating: NutritionEstimate.self)
        return response.content
    }

    /// Generates a short, practical cooking tip for a given recipe step.
    func cookingTip(for step: String) async throws -> String {
        let session = LanguageModelSession()
        let fullPrompt = "\(languageInstruction)Give me a very short, practical cooking tip for this step: \(step)"
        let response = try await session.respond(to: fullPrompt, generating: CookingTip.self)
        return response.content.tip
    }

    // MARK: - Lessons

    /// Generates a short, beginner-friendly cooking lesson (a technique, taught
    /// step by step, similar to a Duolingo lesson) from a title prompt.
    func generateLesson(from prompt: String) async throws -> ParsedLesson {
        let session = LanguageModelSession()
        let fullPrompt = "\(languageInstruction)Create a short, beginner-friendly cooking lesson, similar to a Duolingo-style lesson, that teaches this cooking technique step by step: \(prompt). Respond structured with a title, ingredients or tools used, and a sequence of teaching steps."
        let response = try await session.respond(to: fullPrompt, generating: ParsedLesson.self)
        return response.content
    }

    /// Scans an image and extracts a lesson (title + ingredients + steps) using OCR and the language model.
    func scanLesson(image: UIImage) async throws -> ParsedLesson {
        let session = LanguageModelSession()
        let rawText = try await extractText(from: image)
        guard !rawText.isEmpty else { throw ScanError.noTextFound }
        let fullPrompt = "\(languageInstruction)Extract a cooking lesson from this text. Return the title, ingredients or tools used, and teaching steps: \(rawText)"
        let response = try await session.respond(to: fullPrompt, generating: ParsedLesson.self)
        return response.content
    }

    // MARK: - Allergen check

    /// Returns the subset of `ingredients` whose text matches one of the comma/
    /// semicolon separated terms in `allergies`. Used to show a non-blocking
    /// warning after a recipe was generated or scanned.
    static func potentialAllergens(in ingredients: [String], allergies: String) -> [String] {
        let terms = allergies
            .lowercased()
            .split(whereSeparator: { $0 == "," || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !terms.isEmpty else { return [] }

        return ingredients.filter { ingredient in
            let lower = ingredient.lowercased()
            return terms.contains { lower.contains($0) }
        }
    }

    // MARK: - Categorization

    /// A single item to categorize, tagged by a stable id (usually a UUID
    /// string) so the model's response can be matched back to the right
    /// recipe/lesson without relying on the (possibly non-unique) title.
    struct CategorizableItem {
        let id: String
        let title: String
    }

    /// Asks the model to group the given items into whichever categories make
    /// the most sense for this exact list — e.g. Frühstück/Mittagessen/
    /// Abendessen for a mixed set of recipes, or Backen/Kochen for lessons.
    /// The categories are **not** fixed in code; the model decides based on
    /// the actual titles it's given. Returns a dictionary from item id to its
    /// assigned category name.
    func categorize(_ items: [CategorizableItem], contextHint: String = "") async throws -> [String: String] {
        guard !items.isEmpty else { return [:] }

        let session = LanguageModelSession()
        let listing = items.map { "- id: \($0.id) | title: \($0.title)" }.joined(separator: "\n")

        var fullPrompt = "\(languageInstruction)Group the following items into a small number of sensible categories that best fit this exact list (for example meal times like breakfast/lunch/dinner, or types like baking/cooking/grilling — choose whatever grouping fits best for this specific list, don't force categories that don't apply). Keep category names short (one or two words). Every item must get exactly one category, and the id in your response must be copied exactly as given, unmodified."
        if !contextHint.isEmpty {
            fullPrompt += " Context: \(contextHint)."
        }
        fullPrompt += " Items:\n\(listing)"

        let response = try await session.respond(to: fullPrompt, generating: CategorizationResult.self)

        var result: [String: String] = [:]
        for item in response.content.items {
            result[item.id] = item.category
        }
        return result
    }

    // MARK: - Text Extraction

    /// Uses Vision's text recognition to extract raw text from a UIImage.
    private func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw ScanError.invalidImage }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error { continuation.resume(throwing: error); return }
                let text = request.results?
                    .compactMap { ($0 as? VNRecognizedTextObservation)?.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["de", "en"]
            request.usesLanguageCorrection = true
            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                // Ohne dies würde `perform` bei einem synchronen Fehler
                // (z. B. nicht unterstütztes Bildformat) nie den
                // Completion-Handler aufrufen — die Continuation bliebe
                // für immer unresumed und der Aufruf würde ewig hängen.
                continuation.resume(throwing: error)
            }
        }
    }
}
