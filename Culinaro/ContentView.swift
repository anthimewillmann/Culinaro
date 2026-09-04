import SwiftUI

struct ContentView: View {
    private enum AppTab: Hashable { case recipes, lessons, shoppingList, health, stats }

    @EnvironmentObject private var recipes: RecipeStore
    @EnvironmentObject private var lessons: LessonStore
    @EnvironmentObject private var stats: StatsStore
    @State private var backgroundMode = BackgroundModeManager()
    @State private var gameCenter = GameCenterManager.shared
    @State private var selection: AppTab = .recipes
    @State private var showAddItem = false
    @State private var showAddShoppingItem = false
    @State private var showAddHealthRecipe = false
    @State private var isSelectingRecipes = false
    @State private var isSelectingLessons = false

    @State private var recipePath: [UUID] = []
    @State private var lessonPath: [UUID] = []

    @State private var recipeCategoriesByID: [UUID: String] = [:]
    @State private var recipeCategoryOrder: [String] = []
    @State private var isCategorizingRecipes = false
    @State private var lastRecipeCategorizationSignature: String?

    @State private var lessonCategoriesByID: [UUID: String] = [:]
    @State private var lessonCategoryOrder: [String] = []
    @State private var isCategorizingLessons = false
    @State private var lastLessonCategorizationSignature: String?

    @State private var shoppingCategoriesByID: [UUID: String] = [:]
    @State private var shoppingCategoryOrder: [String] = []
    @State private var isCategorizingShopping = false
    @State private var lastShoppingCategorizationSignature: String?

    var body: some View {
        TabView(selection: $selection) {
            Tab(String(localized: "tab_recipes"), systemImage: "fork.knife", value: .recipes) {
                NavigationStack(path: $recipePath) {
                    RecipesView(
                        isSelecting: $isSelectingRecipes,
                        navigationPath: $recipePath,
                        categoriesByID: $recipeCategoriesByID,
                        categoryOrder: $recipeCategoryOrder,
                        isCategorizing: $isCategorizingRecipes,
                        lastCategorizedSignature: $lastRecipeCategorizationSignature
                    )
                        .toolbar { addButtonToolbar }
                        .navigationDestination(for: UUID.self) { recipeID in
                            if let recipe = recipes.recipes.first(where: { $0.id == recipeID }) {
                                CookModeView(item: recipe)
                            } else {
                                ContentUnavailableView("recipe_not_found", systemImage: "fork.knife")
                            }
                        }
                }
                .toolbar(recipePath.isEmpty && !isSelectingRecipes ? .visible : .hidden, for: .tabBar)
            }

            Tab(String(localized: "tab_lessons"), systemImage: "graduationcap", value: .lessons) {
                NavigationStack(path: $lessonPath) {
                    LessonsView(
                        isSelecting: $isSelectingLessons,
                        navigationPath: $lessonPath,
                        categoriesByID: $lessonCategoriesByID,
                        categoryOrder: $lessonCategoryOrder,
                        isCategorizing: $isCategorizingLessons,
                        lastCategorizedSignature: $lastLessonCategorizationSignature
                    )
                        .toolbar { addButtonToolbar }
                        .navigationDestination(for: UUID.self) { lessonID in
                            if let lesson = lessons.lessons.first(where: { $0.id == lessonID }) {
                                CookModeView(item: lesson)
                            } else {
                                ContentUnavailableView("lesson_not_found", systemImage: "graduationcap")
                            }
                        }
                }
                .toolbar(lessonPath.isEmpty && !isSelectingLessons ? .visible : .hidden, for: .tabBar)
            }

            Tab(String(localized: "tab_shopping"), systemImage: "cart", value: .shoppingList) {
                NavigationStack {
                    ShoppingListView(
                        categoriesByID: $shoppingCategoriesByID,
                        categoryOrder: $shoppingCategoryOrder,
                        isCategorizing: $isCategorizingShopping,
                        lastCategorizedSignature: $lastShoppingCategorizationSignature
                    )
                        .toolbar { addButtonToolbar }
                }
            }

            Tab(String(localized: "tab_nutrition"), systemImage: "heart.text.square", value: .health) {
                NavigationStack {
                    HealthView()
                        .toolbar { addButtonToolbar }
                }
            }

            Tab(String(localized: "tab_overview"), systemImage: "chart.bar", value: .stats) {
                NavigationStack {
                    StatsView()
                }
            }
        }
        .toolbarBackground(.hidden, for: .tabBar)
        .environment(backgroundMode)
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
            // Reset only tab-specific navigation and selection state so the
            // animated background remains mounted across tab changes.
            switch oldValue {
            case .recipes:
                recipePath = []
                isSelectingRecipes = false

            case .lessons:
                lessonPath = []
                isSelectingLessons = false

            case .shoppingList, .health, .stats:
                break
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddItemView(initialKind: selection == .lessons ? .lesson : .recipe)
        }
        .sheet(isPresented: $showAddShoppingItem) {
            AddShoppingListItemSheet()
        }
        .sheet(isPresented: $showAddHealthRecipe) {
            AddHealthRecipeSheet()
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

    private var addButtonAccessibilityLabel: String {
        switch selection {
        case .shoppingList:
            return String(localized: "add_ingredient")
        case .health:
            return String(localized: "add_recipe")
        case .recipes, .lessons, .stats:
            return String(localized: "create_new")
        }
    }

    private var isSelectionModeActive: Bool {
        switch selection {
        case .recipes:
            return isSelectingRecipes
        case .lessons:
            return isSelectingLessons
        case .shoppingList, .health, .stats:
            return false
        }
    }

    private var isSelectionButtonDisabled: Bool {
        switch selection {
        case .recipes:
            return recipes.recipes.isEmpty
        case .lessons:
            return lessons.lessons.isEmpty
        case .shoppingList, .health, .stats:
            return true
        }
    }

    @ToolbarContentBuilder
    private var addButtonToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if isSelectionModeActive {
                Button {
                    withAnimation {
                        switch selection {
                        case .recipes:
                            isSelectingRecipes = false
                        case .lessons:
                            isSelectingLessons = false
                        case .shoppingList, .health, .stats:
                            break
                        }
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(.blue)
                .accessibilityLabel("finish_selection")
            } else {
                if selection == .recipes || selection == .lessons {
                    Button {
                        withAnimation {
                            switch selection {
                            case .recipes:
                                isSelectingRecipes = true
                            case .lessons:
                                isSelectingLessons = true
                            case .shoppingList, .health, .stats:
                                break
                            }
                        }
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .disabled(isSelectionButtonDisabled)
                    .accessibilityLabel("select")
                }

                Button {
                    switch selection {
                    case .shoppingList:
                        showAddShoppingItem = true
                    case .health:
                        showAddHealthRecipe = true
                    case .recipes, .lessons, .stats:
                        showAddItem = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(addButtonAccessibilityLabel)
            }
        }

    }
}
