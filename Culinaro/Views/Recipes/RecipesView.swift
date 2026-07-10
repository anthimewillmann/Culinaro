import SwiftUI

/// Zeigt alle Rezepte, gruppiert in Sections, deren Überschriften vom Modell
/// selbst festgelegt werden (z. B. Frühstück/Mittagessen/Abendessen) — passend
/// zum aktuell vorhandenen Titel-Set. Innerhalb einer Kategorie bleibt die
/// gewohnte Sortierung (angepinnt zuerst, dann neueste zuerst) erhalten.
struct RecipesView: View {
    @EnvironmentObject private var store: RecipeStore
    @Environment(RecipeAIService.self) private var aiService
    @State private var editingRecipe: Recipe?
    @State private var categoriesByID: [UUID: String] = [:]
    @State private var categoryOrder: [String] = []

    private var recipes: [Recipe] {
        store.recipes.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.createdAt > $1.createdAt
        }
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
        .task(id: categorizationSignature) {
            await categorize()
        }
    }

    @ViewBuilder
    private func row(for recipe: Recipe) -> some View {
        NavigationLink { CookModeView(item: recipe) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title).fontWeight(.semibold)
                    Text("\(recipe.steps.count) Schritte").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if recipe.isPinned { Image(systemName: "pin.fill").foregroundStyle(.orange) }
            }
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
            if let pdf = PDFExporter.export(recipe) {
                ShareLink(item: pdf, preview: SharePreview(recipe.title, image: Image(systemName: "doc.richtext"))) {
                    Label("Als PDF teilen", systemImage: "square.and.arrow.up")
                }
            }
            Button(role: .destructive) { store.delete(recipe) } label: { Label("Löschen", systemImage: "trash") }
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
