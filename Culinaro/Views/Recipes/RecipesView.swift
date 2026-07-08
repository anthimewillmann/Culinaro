import SwiftUI

struct RecipesView: View {
    @EnvironmentObject private var store: RecipeStore
    @State private var editingRecipe: Recipe?

    private var recipes: [Recipe] {
        store.recipes.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.createdAt > $1.createdAt
        }
    }

    var body: some View {
        List(recipes) { recipe in
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
        .overlay { if recipes.isEmpty { ContentUnavailableView("Noch keine Rezepte", systemImage: "fork.knife") } }
        .navigationTitle("Rezepte")
        .navigationSubtitle("\(store.recipes.count) erstellt")
        .refreshable { await store.syncFromCloud() }
        .sheet(item: $editingRecipe) { AddItemView(editingRecipe: $0) }
    }
}
