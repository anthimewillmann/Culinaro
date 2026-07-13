import SwiftUI

@main
struct CulinaroApp: App {
    @StateObject private var recipeStore: RecipeStore
    @StateObject private var lessonStore: LessonStore
    @StateObject private var statsStore: StatsStore
    @StateObject private var nutritionStore: NutritionStore
    @StateObject private var shoppingListStore: ShoppingListStore
    @State private var aiService = RecipeAIService()

    init() {
        let recipeStore = RecipeStore()
        _recipeStore = StateObject(wrappedValue: recipeStore)
        _lessonStore = StateObject(wrappedValue: LessonStore())
        _statsStore = StateObject(wrappedValue: StatsStore())
        _nutritionStore = StateObject(wrappedValue: NutritionStore())
        _shoppingListStore = StateObject(wrappedValue: ShoppingListStore { recipeID in
            recipeStore.recipes.first { $0.id == recipeID }
        })
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recipeStore)
                .environmentObject(lessonStore)
                .environmentObject(statsStore)
                .environmentObject(nutritionStore)
                .environmentObject(shoppingListStore)
                .environment(aiService)
        }
    }
}
