import SwiftUI

struct SearchResultsView: View {
    @EnvironmentObject private var recipes: RecipeStore
    @EnvironmentObject private var lessons: LessonStore
    @EnvironmentObject private var shoppingList: ShoppingListStore
    @State private var query = ""

    private var matchingRecipes: [Recipe] { recipes.recipes.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) } }
    private var matchingLessons: [Lesson] { lessons.lessons.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) } }
    private var matchingShoppingItems: [ShoppingListItem] {
        shoppingList.items.filter { item in
            query.isEmpty || item.name.localizedCaseInsensitiveContains(query) || item.sourceRecipeTitle?.localizedCaseInsensitiveContains(query) == true
        }
    }

    var body: some View {
        List {
            if !matchingRecipes.isEmpty {
                Section("Rezepte") {
                    ForEach(matchingRecipes) { recipe in
                        NavigationLink(recipe.title) { CookModeView(item: recipe) }
                    }
                }
            }
            if !matchingLessons.isEmpty {
                Section("Lektionen") {
                    ForEach(matchingLessons) { lesson in
                        NavigationLink(lesson.title) { CookModeView(item: lesson) }
                    }
                }
            }
            if !matchingShoppingItems.isEmpty {
                Section("Einkauf") {
                    ForEach(matchingShoppingItems) { item in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                            if let sourceRecipeTitle = item.sourceRecipeTitle {
                                Text("aus \(sourceRecipeTitle)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if !query.isEmpty && matchingRecipes.isEmpty && matchingLessons.isEmpty && matchingShoppingItems.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle("Suchen")
        .searchable(text: $query, prompt: "Rezepte, Lektionen und Einkauf")
    }
}
