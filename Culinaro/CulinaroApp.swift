import SwiftUI

@main
struct CulinaroApp: App {
    @StateObject private var recipeStore = RecipeStore()
    @StateObject private var lessonStore = LessonStore()
    @StateObject private var statsStore = StatsStore()
    @State private var aiService = RecipeAIService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recipeStore)
                .environmentObject(lessonStore)
                .environmentObject(statsStore)
                .environment(aiService)
        }
    }
}
