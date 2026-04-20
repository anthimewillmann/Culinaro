import Foundation
import FoundationModels
import Vision
import UIKit

@Observable
final class RecipeAIService {
    private let session = LanguageModelSession()
    
    func generate(from prompt: String) async throws -> ParsedRecipe {
        let fullPrompt = "Erstelle ein vollständiges Rezept für: \(prompt). Antworte strukturiert mit Titel, Zutaten und Schritten."
        let response = try await session.respond(to: fullPrompt, generating: ParsedRecipe.self)
        return response.content
    }
    
    func scan(image: UIImage) async throws -> ParsedRecipe {
        let rawText = try await extractText(from: image)
        guard !rawText.isEmpty else { throw ScanError.noTextFound }
        let response = try await session.respond(to: "Extrahiere Rezept aus: \(rawText)", generating: ParsedRecipe.self)
        return response.content
    }
    
    func cookingTip(for step: String) async throws -> String {
        let prompt = "Gib mir einen sehr kurzen, praktischen Kochtipp für diesen Schritt: \(step)"
        let response = try await session.respond(to: prompt, generating: CookingTip.self)
        return response.content.tip
    }
    
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
