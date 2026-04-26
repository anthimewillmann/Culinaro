import FoundationModels

@Generable
struct CookingTip {
    @Guide(description: "A short, helpful cooking tip (max. 15 words)")
    var tip: String
}
