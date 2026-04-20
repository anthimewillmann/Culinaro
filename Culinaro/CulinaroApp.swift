import SwiftUI

@main
struct CulinaroApp: App {
    @StateObject private var store = RecipeStore()
    @State private var aiService = RecipeAIService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environment(aiService)
        }
    }
}
