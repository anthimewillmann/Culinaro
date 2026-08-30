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
                Section("recipes") {
                    ForEach(matchingRecipes) { recipe in
                        NavigationLink(recipe.title) { CookModeView(item: recipe) }
                    }
                }
            }
            if !matchingLessons.isEmpty {
                Section("lessons") {
                    ForEach(matchingLessons) { lesson in
                        NavigationLink(lesson.title) { CookModeView(item: lesson) }
                    }
                }
            }
            if !matchingShoppingItems.isEmpty {
                Section("shopping") {
                    ForEach(matchingShoppingItems) { item in
                        Button {
                            shoppingList.toggleChecked(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name)
                                if let sourceRecipeTitle = item.sourceRecipeTitle {
                                    Text(String.localizedStringWithFormat(String(localized: "from_source"), sourceRecipeTitle))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .overlay {
            if !query.isEmpty && matchingRecipes.isEmpty && matchingLessons.isEmpty && matchingShoppingItems.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle("search")
        .searchable(text: $query, prompt: "search_prompt")
    }
}
