import Foundation

protocol Cookable: Identifiable {
    var id: UUID { get }
    var title: String { get }
    var ingredients: [String] { get }
    var steps: [String] { get }
    var tipsEnabled: Bool { get }
    var completionKind: CompletionKind { get }
}

enum CompletionKind {
    case recipe
    case lesson
}
