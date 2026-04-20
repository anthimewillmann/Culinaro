import SwiftUI

struct ContentView: View {
    @StateObject private var store = RecipeStore()

    var body: some View {
        NavigationStack {
            RecipesView()
        }
        .environmentObject(store)
    }
}
