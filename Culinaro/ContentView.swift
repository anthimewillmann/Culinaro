import SwiftUI

struct ContentView: View {
    private enum AppTab: Hashable { case recipes, lessons, stats }

    @EnvironmentObject private var recipes: RecipeStore
    @EnvironmentObject private var lessons: LessonStore
    @EnvironmentObject private var stats: StatsStore
    @State private var gameCenter = GameCenterManager.shared
    @State private var selection: AppTab = .recipes
    @State private var showAddItem = false
    @State private var recipeSearchText = ""
    @State private var lessonSearchText = ""

    @State private var recipesStackID = UUID()
    @State private var lessonsStackID = UUID()

    var body: some View {
        TabView(selection: $selection) {
            Tab("Rezepte", systemImage: "fork.knife", value: .recipes) {
                NavigationStack {
                    RecipesView()
                        .toolbar { addButtonToolbar }
                        .searchable(text: $recipeSearchText, placement: .toolbar)
                        .searchToolbarBehavior(.minimize)
                }
                .id(recipesStackID)
            }

            Tab("Lektionen", systemImage: "graduationcap", value: .lessons) {
                NavigationStack {
                    LessonsView()
                        .toolbar { addButtonToolbar }
                        .searchable(text: $lessonSearchText, placement: .toolbar)
                        .searchToolbarBehavior(.minimize)
                }
                .id(lessonsStackID)
            }

            Tab("Übersicht", systemImage: "chart.bar", value: .stats) {
                NavigationStack {
                    StatsView()
                }
            }
        }
        .onAppear {
            gameCenter.authenticate()
            submitTotalScore()
        }
        .onChange(of: gameCenter.isAuthenticated) { _, isAuthenticated in
            guard isAuthenticated else { return }
            submitTotalScore()
        }
        .onChange(of: recipes.totalCreatedRecipes) { _, _ in submitTotalScore() }
        .onChange(of: lessons.totalCreatedLessons) { _, _ in submitTotalScore() }
        .onChange(of: stats.completedCookModes) { _, _ in submitTotalScore() }
        .onChange(of: stats.completedLessons) { _, _ in submitTotalScore() }
        .onChange(of: selection) { oldValue, newValue in
            switch oldValue {
            case .recipes:
                recipeSearchText = ""
                recipesStackID = UUID()

            case .lessons:
                lessonSearchText = ""
                lessonsStackID = UUID()

            case .stats:
                break
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddItemView(initialKind: selection == .lessons ? .lesson : .recipe)
        }
    }

    private var totalScore: Int {
        recipes.totalCreatedRecipes + lessons.totalCreatedLessons + stats.completedCookModes + stats.completedLessons
    }

    private func submitTotalScore() {
        Task {
            await gameCenter.submitTotalScore(totalScore)
        }
    }

    @ToolbarContentBuilder
    private var addButtonToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showAddItem = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Neu erstellen")
        }

        ToolbarSpacer(.flexible, placement: .topBarTrailing)

        DefaultToolbarItem(kind: .search, placement: .topBarTrailing)
    }
}
