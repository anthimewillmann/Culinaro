import SwiftUI

struct ContentView: View {
    private enum AppTab: Hashable { case recipes, lessons, shoppingList, health, stats }

    @EnvironmentObject private var recipes: RecipeStore
    @EnvironmentObject private var lessons: LessonStore
    @EnvironmentObject private var stats: StatsStore
    @State private var gameCenter = GameCenterManager.shared
    @State private var selection: AppTab = .recipes
    @State private var showAddItem = false
    @State private var showAddShoppingItem = false
    @State private var recipeSearchText = ""
    @State private var lessonSearchText = ""
    @State private var shoppingSearchText = ""

    @State private var recipesStackID = UUID()
    @State private var lessonsStackID = UUID()
    @State private var shoppingStackID = UUID()
    @State private var recipePath: [UUID] = []
    @State private var lessonPath: [UUID] = []

    var body: some View {
        TabView(selection: $selection) {
            Tab("Rezepte", systemImage: "fork.knife", value: .recipes) {
                NavigationStack(path: $recipePath) {
                    RecipesView()
                        .toolbar { addButtonToolbar }
                        .searchable(text: $recipeSearchText, placement: .toolbar)
                        .searchToolbarBehavior(.minimize)
                        .navigationDestination(for: UUID.self) { recipeID in
                            if let recipe = recipes.recipes.first(where: { $0.id == recipeID }) {
                                CookModeView(item: recipe)
                            } else {
                                ContentUnavailableView("Rezept nicht gefunden", systemImage: "fork.knife")
                            }
                        }
                }
                .toolbar(recipePath.isEmpty ? .visible : .hidden, for: .tabBar)
                .id(recipesStackID)
            }

            Tab("Lektionen", systemImage: "graduationcap", value: .lessons) {
                NavigationStack(path: $lessonPath) {
                    LessonsView()
                        .toolbar { addButtonToolbar }
                        .searchable(text: $lessonSearchText, placement: .toolbar)
                        .searchToolbarBehavior(.minimize)
                        .navigationDestination(for: UUID.self) { lessonID in
                            if let lesson = lessons.lessons.first(where: { $0.id == lessonID }) {
                                CookModeView(item: lesson)
                            } else {
                                ContentUnavailableView("Lektion nicht gefunden", systemImage: "graduationcap")
                            }
                        }
                }
                .toolbar(lessonPath.isEmpty ? .visible : .hidden, for: .tabBar)
                .id(lessonsStackID)
            }

            Tab("Einkauf", systemImage: "cart", value: .shoppingList) {
                NavigationStack {
                    ShoppingListView(searchText: shoppingSearchText)
                        .toolbar { addButtonToolbar }
                        .searchable(text: $shoppingSearchText, placement: .toolbar)
                        .searchToolbarBehavior(.minimize)
                }
                .id(shoppingStackID)
            }

            Tab("Ernährung", systemImage: "heart.text.square", value: .health) {
                NavigationStack {
                    HealthView()
                }
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
        .onChange(of: selection) { oldValue, _ in
            switch oldValue {
            case .recipes:
                recipeSearchText = ""
                recipePath = []
                recipesStackID = UUID()

            case .lessons:
                lessonSearchText = ""
                lessonPath = []
                lessonsStackID = UUID()

            case .shoppingList:
                shoppingSearchText = ""
                shoppingStackID = UUID()

            case .health, .stats:
                break
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddItemView(initialKind: selection == .lessons ? .lesson : .recipe)
        }
        .sheet(isPresented: $showAddShoppingItem) {
            AddShoppingListItemSheet()
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
                if selection == .shoppingList {
                    showAddShoppingItem = true
                } else {
                    showAddItem = true
                }
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel(selection == .shoppingList ? "Artikel hinzufügen" : "Neu erstellen")
        }

        ToolbarSpacer(.flexible, placement: .topBarTrailing)

        DefaultToolbarItem(kind: .search, placement: .topBarTrailing)
    }
}
