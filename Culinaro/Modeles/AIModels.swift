import Foundation
import FoundationModels

struct TextRow: Identifiable, Equatable {
    let id: UUID
    var text: String
    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

enum ScanError: LocalizedError {
    case invalidImage
    case noTextFound
    var errorDescription: String? {
        switch self {
        case .invalidImage: return NSLocalizedString("error_invalid_image", comment: "")
        case .noTextFound: return NSLocalizedString("error_no_text_found", comment: "")
        }
    }
}

@Generable
struct ParsedRecipe {
    @Guide(description: "Der Titel des Rezepts")
    var title: String
    @Guide(description: "Liste der Zutaten")
    var ingredients: [String]
    @Guide(description: "Zubereitungsschritte")
    var steps: [String]
}
