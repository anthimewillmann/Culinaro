import Foundation
import FoundationModels
import Vision
import UIKit

/// Service that interfaces with Apple Intelligence via FoundationModels.
///
/// Provides three capabilities:
/// - `generate(from:)` – Creates a full recipe from a title string.
/// - `scan(image:)` – Extracts a recipe from a photo using Vision + LLM.
/// - `cookingTip(for:)` – Generates a short tip for a single cooking step.
@Observable
final class RecipeAIService {

    /// Returns a language instruction based on the device's current locale.
    private var languageInstruction: String {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        return "Respond in the language with code '\(lang)'. "
    }

    /// Generates a complete recipe from a plain-text title prompt.
    /// - Parameter prompt: The recipe idea or dish name.
    /// - Returns: A `ParsedRecipe` with title, ingredients, and steps.
    func generate(from prompt: String) async throws -> ParsedRecipe {
        let session = LanguageModelSession()
        let fullPrompt = "\(languageInstruction)Create a complete recipe for: \(prompt). Respond structured with title, ingredients and steps."
        let response = try await session.respond(to: fullPrompt, generating: ParsedRecipe.self)
        return response.content
    }

    /// Scans an image and extracts a recipe using OCR and the language model.
    /// - Parameter image: A photo containing a printed or handwritten recipe.
    /// - Returns: A `ParsedRecipe` extracted from the image text.
    /// - Throws: `ScanError.noTextFound` if no text could be recognised.
    func scan(image: UIImage) async throws -> ParsedRecipe {
        let session = LanguageModelSession()
        let rawText = try await extractText(from: image)
        guard !rawText.isEmpty else { throw ScanError.noTextFound }
        let fullPrompt = "\(languageInstruction)Extract recipe from: \(rawText)"
        let response = try await session.respond(to: fullPrompt, generating: ParsedRecipe.self)
        return response.content
    }

    /// Generates a short, practical cooking tip for a given recipe step.
    /// - Parameter step: The text of a single cooking step.
    /// - Returns: A brief tip string.
    func cookingTip(for step: String) async throws -> String {
        let session = LanguageModelSession()
        let fullPrompt = "\(languageInstruction)Give me a very short, practical cooking tip for this step: \(step)"
        let response = try await session.respond(to: fullPrompt, generating: CookingTip.self)
        return response.content.tip
    }

    /// Uses Vision's text recognition to extract raw text from a UIImage.
    /// - Parameter image: The source image.
    /// - Returns: A concatenated string of all recognised text lines.
    /// - Throws: `ScanError.invalidImage` if the image has no CGImage representation.
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
            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        }
    }
}
