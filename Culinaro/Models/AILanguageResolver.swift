import Foundation
import FoundationModels
import NaturalLanguage

enum AILanguageMode {
    case inputLanguageWithFallback(String)
    case appLanguage
}

enum AILanguageResolver {
    static let detectionConfidenceThreshold = 0.65
    static let hardFallbackIdentifier = "en"

    /// Resolves the language for every Foundation Models request.
    ///
    /// Manual input uses its detected language only when the recognizer is
    /// sufficiently confident. All other requests use the selected app
    /// localization, then the system language, and finally English.
    static func languageIdentifier(
        for mode: AILanguageMode,
        model: SystemLanguageModel = .default
    ) -> String {
        let candidate: String

        switch mode {
        case .inputLanguageWithFallback(let input):
            candidate = detectedLanguage(in: input) ?? preferredLanguageIdentifier
        case .appLanguage:
            candidate = preferredLanguageIdentifier
        }

        return supportedLanguageIdentifier(candidate, model: model)
    }

    static func instruction(for mode: AILanguageMode) -> String {
        let identifier = languageIdentifier(for: mode)
        return """
        Respond only in the target language '\(identifier)'. All user-visible text, including titles, ingredients, steps, tips, and category names, must use this language regardless of the language used by the app's prompt text.
        """
    }

    /// Puts the resolved app language first while retaining the previous German
    /// and English OCR coverage as fallbacks.
    static var ocrRecognitionLanguages: [String] {
        var identifiers = [languageIdentifier(for: .appLanguage), "de", "en"]
        var seen = Set<String>()
        identifiers = identifiers.filter { seen.insert($0).inserted }
        return identifiers
    }

    private static var preferredLanguageIdentifier: String {
        if let appLanguage = Bundle.main.preferredLocalizations.first,
           !appLanguage.isEmpty,
           appLanguage != "Base" {
            return appLanguage
        }

        if let systemLanguage = Locale.preferredLanguages.first,
           !systemLanguage.isEmpty {
            return systemLanguage
        }

        return hardFallbackIdentifier
    }

    private static func detectedLanguage(in input: String) -> String? {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmedInput)

        guard let bestHypothesis = recognizer.languageHypotheses(withMaximum: 1).max(by: {
            $0.value < $1.value
        }),
        bestHypothesis.value >= detectionConfidenceThreshold else {
            return nil
        }

        return bestHypothesis.key.rawValue
    }

    private static func supportedLanguageIdentifier(
        _ identifier: String,
        model: SystemLanguageModel
    ) -> String {
        let locale = Locale(identifier: identifier)
        guard model.supportsLocale(locale) else {
            return hardFallbackIdentifier
        }

        return identifier
    }
}
