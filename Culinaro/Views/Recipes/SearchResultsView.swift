import SwiftUI

struct SearchResultsView: View {
    @EnvironmentObject private var recipes: RecipeStore
    @EnvironmentObject private var lessons: LessonStore
    @State private var query = ""

    private var matchingRecipes: [Recipe] { recipes.recipes.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) } }
    private var matchingLessons: [Lesson] { lessons.lessons.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) } }

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
        }
        .overlay {
            if !query.isEmpty && matchingRecipes.isEmpty && matchingLessons.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle("Suchen")
        .searchable(text: $query, prompt: "Rezepte und Lektionen")
    }
}
