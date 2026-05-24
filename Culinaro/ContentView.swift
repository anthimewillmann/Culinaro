import SwiftUI

/// Root view that embeds the recipe list inside a `NavigationStack`
/// and injects the `RecipeStore` into the environment.
struct ContentView: View {
    @StateObject private var store = RecipeStore()

    var body: some View {
        NavigationStack {
            RecipesView()
        }
        .environmentObject(store)
    }
}
