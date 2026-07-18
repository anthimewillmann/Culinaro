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
    @State private var editingRecipe: Recipe?
    @State private var categoriesByID: [UUID: String] = [:]
    @State private var categoryOrder: [String] = []
    @Binding var isSelecting: Bool
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

    /// Rezepte gruppiert nach KI-Kategorie, in der Reihenfolge, in der die
    /// Kategorien erstmals in der Modell-Antwort auftauchten. Noch nicht
    /// kategorisierte (z. B. gerade erst hinzugefügte) Rezepte landen unter
    /// "Weitere", bis die nächste Einteilung fertig ist.
    private var groupedRecipes: [(category: String, recipes: [Recipe])] {
        let groups = Dictionary(grouping: recipes) { categoriesByID[$0.id] ?? "Weitere" }
        let orderedKeys = categoryOrder + groups.keys.filter { !categoryOrder.contains($0) }.sorted()
        return orderedKeys.compactMap { key in
            guard let items = groups[key], !items.isEmpty else { return nil }
            return (key, items)
        }
    }

    /// Ändert sich nur, wenn sich die Rezepte selbst ändern (hinzugefügt,
    /// gelöscht, umbenannt) — nicht bei Pin-Toggle o. Ä., damit nicht bei
    /// jeder Kleinigkeit neu kategorisiert wird.
    private var categorizationSignature: String {
        recipes.map { "\($0.id.uuidString):\($0.title)" }.joined(separator: "|")
    }

    var body: some View {
        List {
            ForEach(groupedRecipes, id: \.category) { group in
                Section(group.category) {
                    ForEach(group.recipes) { recipe in
                        row(for: recipe)
                    }
                }
            }
        }
        .overlay { if recipes.isEmpty { ContentUnavailableView("Noch keine Rezepte", systemImage: "fork.knife") } }
        .navigationTitle("Rezepte")
        .navigationSubtitle("\(store.recipes.count) erstellt")
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
            NavigationLink(value: recipe.id) {
                rowContent(for: recipe)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { store.delete(recipe) } label: { Label("Löschen", systemImage: "trash") }
                Button { editingRecipe = recipe } label: { Label("Bearbeiten", systemImage: "pencil") }.tint(.blue)
            }
            .swipeActions(edge: .leading) {
                Button { withAnimation { store.togglePin(recipe) } } label: {
                    Label(recipe.isPinned ? "Lösen" : "Anpinnen", systemImage: recipe.isPinned ? "pin.slash" : "pin")
                }.tint(.orange)
            }
            .contextMenu {
                Button { editingRecipe = recipe } label: { Label("Bearbeiten", systemImage: "pencil") }
                Button { store.togglePin(recipe) } label: { Label(recipe.isPinned ? "Lösen" : "Anpinnen", systemImage: "pin") }
                Button { shoppingListStore.addIngredients(from: recipe) } label: { Label("Zutaten zum Einkauf", systemImage: "cart.badge.plus") }
                if let pdf = PDFExporter.export(recipe) {
                    ShareLink(item: pdf, preview: SharePreview(recipe.title, image: Image(systemName: "doc.richtext"))) {
                        Label("Exportieren", systemImage: "square.and.arrow.up")
                    }
                }
                Button(role: .destructive) { store.delete(recipe) } label: { Label("Löschen", systemImage: "trash") }
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
            if recipe.isPinned { Image(systemName: "pin.fill").foregroundStyle(.orange) }
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
                .accessibilityLabel("Zum Einkauf hinzufügen")

                Button {
                    addSelectedNutrition()
                } label: {
                    Image(systemName: "heart.text.square")
                }
                .disabled(!hasSelectedRecipesWithNutrition)
                .accessibilityLabel("Zur Ernährung hinzufügen")

                ShareLink(item: recipeExportForToolbar, preview: SharePreview("Rezepte", image: Image(systemName: "doc.richtext"))) {
                    Label("Exportieren", systemImage: "square.and.arrow.up")
                }
                .disabled(selectedRecipeExport == nil)
                .accessibilityLabel("Ausgewählte Rezepte exportieren")

                Button(role: .destructive) {
                    deleteSelectedRecipes()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(selectedRecipeIDs.isEmpty)
                .accessibilityLabel("Ausgewählte Rezepte löschen")

                Spacer()
            }
        }
    }

    private func recipeSubtitle(for recipe: Recipe) -> String {
        let stepsText = "\(recipe.steps.count) Schritte"
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
            nutritionStore.logMeal(recipe: recipe, servings: 1)
        }
        finishSelection()
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
    /// bleibt alles unter "Weitere" — kein harter Fehlerzustand in der UI.
    private func categorize() async {
        guard !recipes.isEmpty else {
            categoriesByID = [:]
            categoryOrder = []
            return
        }

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
            }
        } catch {
            // Bleibt einfach unkategorisiert unter "Weitere".
        }
    }
}
