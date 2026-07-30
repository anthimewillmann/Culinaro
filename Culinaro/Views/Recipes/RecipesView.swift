import SwiftUI

/// Zeigt alle Rezepte, gruppiert in Sections, deren Überschriften vom Modell
/// selbst festgelegt werden (z. B. Frühstück/Mittagessen/Abendessen) — passend
/// zum aktuell vorhandenen Titel-Set. Innerhalb einer Kategorie bleibt die
/// gewohnte Sortierung (angepinnt zuerst, dann neueste zuerst) erhalten.
struct RecipesView: View {
    @EnvironmentObject private var store: RecipeStore
    @EnvironmentObject private var shoppingListStore: ShoppingListStore
    @EnvironmentObject private var nutritionStore: NutritionStore
    @Environment(RecipeAIService.self) private var aiService
    @Environment(BackgroundModeManager.self) private var backgroundMode
    @State private var editingRecipe: Recipe?
    @State private var categoriesByID: [UUID: String] = [:]
    @State private var categoryOrder: [String] = []
    @State private var isCategorizing = false
    @Binding var isSelecting: Bool
    @Binding var navigationPath: [UUID]

    private let pinnedCategoryID = "__pinnedCategory__"
    private let pendingCategoryID = "__pendingCategory__"
    @State private var selectedRecipeIDs: Set<UUID> = []

    private var recipes: [Recipe] {
        store.recipes.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.createdAt > $1.createdAt
        }
    }

    private var selectedRecipes: [Recipe] {
        recipes.filter { selectedRecipeIDs.contains($0.id) }
    }

    private var hasSelectedRecipesWithNutrition: Bool {
        selectedRecipes.contains { $0.nutrition != nil }
    }

    private var selectedRecipeExport: PDFExport? {
        PDFExporter.export(selectedRecipes.map { $0 as any Cookable }, filename: "Rezepte")
    }

    private var recipeExportForToolbar: PDFExport {
        selectedRecipeExport ?? PDFExport(data: Data(), filename: "Rezepte.pdf")
    }

    /// Rezepte gruppiert nach Pin-Status und KI-Kategorie. Angepinnte Rezepte
    /// stehen immer in einer eigenen Section über den Modell-Kategorien.
    private var groupedRecipes: [(category: String, recipes: [Recipe])] {
        let pinnedRecipes = recipes.filter(\.isPinned)
        let regularRecipes = recipes.filter { !$0.isPinned }
        let groups = Dictionary(grouping: regularRecipes) { categoriesByID[$0.id] ?? pendingCategoryID }
        let orderedKeys = categoryOrder
            + groups.keys.filter { !categoryOrder.contains($0) && $0 != pendingCategoryID }.sorted()
            + (groups[pendingCategoryID]?.isEmpty == false ? [pendingCategoryID] : [])

        var result: [(category: String, recipes: [Recipe])] = []
        if !pinnedRecipes.isEmpty {
            result.append((pinnedCategoryID, pinnedRecipes))
        }
        result += orderedKeys.compactMap { key in
            guard let items = groups[key], !items.isEmpty else { return nil }
            return (key, items)
        }
        return result
    }

    /// Ändert sich nur, wenn sich die Rezepte selbst ändern (hinzugefügt,
    /// gelöscht, umbenannt) — nicht bei Pin-Toggle o. Ä., damit nicht bei
    /// jeder Kleinigkeit neu kategorisiert wird.
    private var categorizationSignature: String {
        store.recipes
            .map { "\($0.id.uuidString):\($0.title)" }
            .sorted()
            .joined(separator: "|")
    }

    var body: some View {
        List {
            ForEach(groupedRecipes, id: \.category) { group in
                Section {
                    ForEach(group.recipes) { recipe in
                        row(for: recipe)
                    }
                } header: {
                    categoryHeader(for: group.category)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .keepingOpaqueBackground()
        .containerBackground(.clear, for: .navigation)
        .overlay { if recipes.isEmpty { ContentUnavailableView("no_recipes", systemImage: "fork.knife") } }
        .navigationTitle("recipes")
        .navigationSubtitle(String.localizedStringWithFormat(String(localized: "created_count"), store.recipes.count))
        .refreshable { await store.syncFromCloud() }
        .sheet(item: $editingRecipe) { AddItemView(editingRecipe: $0) }
        .toolbar { selectionToolbar }
        .onChange(of: isSelecting) { _, isSelecting in
            if !isSelecting { selectedRecipeIDs.removeAll() }
        }
        .onChange(of: recipes) { _, recipes in
            let availableIDs = Set(recipes.map(\.id))
            selectedRecipeIDs = selectedRecipeIDs.intersection(availableIDs)
            if recipes.isEmpty { isSelecting = false }
        }
        .task(id: categorizationSignature) {
            await categorize()
        }
        .task { backgroundMode.mode = .meadow }
    }

    @ViewBuilder
    private func row(for recipe: Recipe) -> some View {
        if isSelecting {
            Button {
                toggleSelection(for: recipe)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: selectedRecipeIDs.contains(recipe.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedRecipeIDs.contains(recipe.id) ? .blue : .secondary)
                        .imageScale(.large)
                    rowContent(for: recipe)
                }
            }
            .buttonStyle(.plain)
        } else {
            Button {
                navigationPath.append(recipe.id)
            } label: {
                rowContent(for: recipe)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { store.delete(recipe) } label: { Label("delete", systemImage: "trash") }
                Button { editingRecipe = recipe } label: { Label("edit", systemImage: "pencil") }.tint(.blue)
                if let pdf = PDFExporter.export(recipe) {
                    ShareLink(item: pdf, preview: SharePreview(recipe.title, image: Image(systemName: "doc.richtext"))) {
                        Label("export", systemImage: "square.and.arrow.up")
                    }
                    .tint(Color(red: 0.48, green: 0.44, blue: 1.0))
                }
            }
            .swipeActions(edge: .leading) {
                Button { withAnimation { store.togglePin(recipe) } } label: {
                    Label(LocalizedStringKey(recipe.isPinned ? "unpin" : "pin"), systemImage: recipe.isPinned ? "pin.slash" : "pin")
                }.tint(.orange)
            }
            .contextMenu {
                Button { editingRecipe = recipe } label: { Label("edit", systemImage: "pencil") }
                Button { store.togglePin(recipe) } label: { Label(LocalizedStringKey(recipe.isPinned ? "unpin" : "pin"), systemImage: "pin") }
                Button { shoppingListStore.addIngredients(from: recipe) } label: { Label("add_ingredients_to_shopping", systemImage: "cart.badge.plus") }
                Button { addNutrition(for: recipe) } label: { Label("add_to_nutrition", systemImage: "heart.text.square") }
                    .disabled(recipe.nutrition == nil)
                if let pdf = PDFExporter.export(recipe) {
                    ShareLink(item: pdf, preview: SharePreview(recipe.title, image: Image(systemName: "doc.richtext"))) {
                        Label("export", systemImage: "square.and.arrow.up")
                    }
                }
                Button(role: .destructive) { store.delete(recipe) } label: { Label("delete", systemImage: "trash") }
            }
        }
    }

    private func rowContent(for recipe: Recipe) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title).fontWeight(.semibold)
                Text(recipeSubtitle(for: recipe)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ToolbarContentBuilder
    private var selectionToolbar: some ToolbarContent {
        if isSelecting {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    addSelectedIngredientsToShoppingList()
                } label: {
                    Image(systemName: "cart.badge.plus")
                }
                .disabled(selectedRecipeIDs.isEmpty)
                .accessibilityLabel("add_to_shopping")

                Button {
                    addSelectedNutrition()
                } label: {
                    Image(systemName: "heart.text.square")
                }
                .disabled(!hasSelectedRecipesWithNutrition)
                .accessibilityLabel("add_to_nutrition")

                ShareLink(item: recipeExportForToolbar, preview: SharePreview(String(localized: "recipes"), image: Image(systemName: "doc.richtext"))) {
                    Label("export", systemImage: "square.and.arrow.up")
                }
                .disabled(selectedRecipeExport == nil)
                .accessibilityLabel("export_selected_recipes")

                Spacer()

                Button {
                    deleteSelectedRecipes()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(selectedRecipeIDs.isEmpty)
                .accessibilityLabel("delete_selected_recipes")
            }
        }
    }

    @ViewBuilder
    private func categoryHeader(for category: String) -> some View {
        if category == pinnedCategoryID {
            Text("pinned")
        } else if category == pendingCategoryID {
            ProgressView()
                .controlSize(.small)
        } else {
            Text(category)
        }
    }

    private func recipeSubtitle(for recipe: Recipe) -> String {
        let displayedStepCount = recipe.steps.count + 1
        let stepsText = String.localizedStringWithFormat(String(localized: "steps_count"), displayedStepCount)
        guard let calories = recipe.nutrition?.calories else { return stepsText }
        return "\(calories) kcal · \(stepsText)"
    }

    private func toggleSelection(for recipe: Recipe) {
        if selectedRecipeIDs.contains(recipe.id) {
            selectedRecipeIDs.remove(recipe.id)
        } else {
            selectedRecipeIDs.insert(recipe.id)
        }
    }

    private func addSelectedIngredientsToShoppingList() {
        for recipe in selectedRecipes {
            shoppingListStore.addIngredients(from: recipe)
        }
        finishSelection()
    }

    private func addSelectedNutrition() {
        for recipe in selectedRecipes where recipe.nutrition != nil {
            addNutrition(for: recipe)
        }
        finishSelection()
    }

    private func addNutrition(for recipe: Recipe) {
        nutritionStore.logMeal(recipe: recipe, servings: 1)
    }

    private func deleteSelectedRecipes() {
        for recipe in selectedRecipes {
            store.delete(recipe)
        }
        finishSelection()
    }

    private func finishSelection() {
        withAnimation {
            selectedRecipeIDs.removeAll()
            isSelecting = false
        }
    }

    /// Lässt das Modell die aktuellen Rezepttitel in sinnvolle Kategorien
    /// einteilen. Schlägt die Einteilung fehl (z. B. Modell nicht verfügbar),
    /// bleibt die Ladeanzeige sichtbar — kein harter Fehlerzustand in der UI.
    private func categorize() async {
        guard !recipes.isEmpty else {
            categoriesByID = [:]
            categoryOrder = []
            isCategorizing = false
            return
        }

        isCategorizing = true
        categoriesByID = [:]
        categoryOrder = []

        let items = recipes.map { RecipeAIService.CategorizableItem(id: $0.id.uuidString, title: $0.title) }
        do {
            let assignments = try await aiService.categorize(items, contextHint: "Diese Einträge sind Kochrezepte")
            var byID: [UUID: String] = [:]
            var order: [String] = []
            for recipe in recipes {
                if let category = assignments[recipe.id.uuidString] {
                    byID[recipe.id] = category
                    if !order.contains(category) { order.append(category) }
                }
            }
            withAnimation {
                categoriesByID = byID
                categoryOrder = order
                isCategorizing = false
            }
        } catch {
            // Bleibt im Ladezustand, damit kein unkategorisierter Text-Fallback erscheint.
        }
    }
}
