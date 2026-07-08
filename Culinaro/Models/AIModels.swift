import FoundationModels

@Generable
struct ParsedLesson {
    @Guide(description: "The title of the cooking lesson")
    var title: String

    @Guide(description: "Clear, ordered learning steps")
    var steps: [String]
}
