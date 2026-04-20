import SwiftUI

struct RecipesView: View {
    @EnvironmentObject var store: RecipeStore
    @State private var searchText = ""
    @State private var showAddRecipe = false
    @State private var editingRecipe: Recipe? = nil

    private var filteredAndSortedRecipes: [Recipe] {
        let filtered = searchText.isEmpty
            ? store.recipes
            : store.recipes.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }

        return filtered.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.createdAt > $1.createdAt
        }
    }

    var body: some View {
        List(filteredAndSortedRecipes) { recipe in
            NavigationLink {
                CookModeView(recipe: recipe)
            } label: {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.title)
                            .fontWeight(.semibold)

                        Text(
                            String.localizedStringWithFormat(
                                NSLocalizedString("steps_count", comment: ""),
                                recipe.steps.count + 1
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.gray)
                    }

                    Spacer()

                    if recipe.isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .buttonStyle(.plain)

            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    store.delete(recipe)
                } label: {
                    Label("delete", systemImage: "trash")
                }

                Button {
                    editingRecipe = recipe
                } label: {
                    Label("edit_recipe", systemImage: "pencil")
                }
                .tint(.blue)
            }

            .swipeActions(edge: .leading) {
                Button {
                    withAnimation {
                        store.togglePin(recipe)
                    }
                } label: {
                    Label(
                        recipe.isPinned ? "unpin" : "pin",
                        systemImage: recipe.isPinned ? "pin.slash" : "pin"
                    )
                }
                .tint(.orange)
            }

            .contextMenu {
                Button {
                    editingRecipe = recipe
                } label: {
                    Label("edit_recipe", systemImage: "pencil")
                }

                Button {
                    store.togglePin(recipe)
                } label: {
                    Label(
                        recipe.isPinned ? "unpin" : "pin",
                        systemImage: "pin"
                    )
                }

                Button(role: .destructive) {
                    store.delete(recipe)
                } label: {
                    Label("delete", systemImage: "trash")
                }
            }
        }
        .navigationTitle("recipes")
        .navigationSubtitle(
            String.localizedStringWithFormat(
                NSLocalizedString("recipes_count", comment: ""),
                store.recipes.count
            )
        )
        .toolbar {
            DefaultToolbarItem(kind: .search, placement: .bottomBar)

            ToolbarSpacer(.fixed, placement: .bottomBar)

            ToolbarItem(placement: .bottomBar) {
                Button {
                    showAddRecipe = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .searchable(text: $searchText)
        // Neues Rezept – sheet mit Drag-Indikator
        .sheet(isPresented: $showAddRecipe) {
            AddRecipeView()
                .environmentObject(store)
        }
        // Rezept bearbeiten – sheet
        .sheet(item: $editingRecipe) { recipe in
            AddRecipeView(editingRecipe: recipe)
                .environmentObject(store)
        }
    }
}
