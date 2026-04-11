import SwiftUI

struct TextRow: Identifiable, Equatable {
    let id: UUID
    var text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

struct AddRecipeView: View {
    @EnvironmentObject var store: RecipeStore
    @Environment(\.dismiss) private var dismiss

    var editingRecipe: Recipe? = nil

    @State private var title: String = ""
    @State private var ingredients: [TextRow] = [TextRow(text: "")]
    @State private var steps: [TextRow] = [TextRow(text: "")]

    init(editingRecipe: Recipe? = nil) {
        self.editingRecipe = editingRecipe
        if let recipe = editingRecipe {
            _title = State(initialValue: recipe.title)
            _ingredients = State(initialValue: recipe.ingredients.map { TextRow(text: $0) } + [TextRow(text: "")])
            _steps = State(initialValue: recipe.steps.map { TextRow(text: $0) } + [TextRow(text: "")])
        }
    }

    var body: some View {
        NavigationStack {
            Form {

                Section(NSLocalizedString("title", comment: "")) {
                    TextField(
                        NSLocalizedString("recipe_title", comment: ""),
                        text: $title
                    )
                }

                Section("ingredients") {
                    ForEach(Array(ingredients.enumerated()), id: \.element.id) { index, row in
                        numberedRow(
                            number: index + 1,
                            placeholder: NSLocalizedString("ingredient", comment: ""),
                            text: rowBinding(in: $ingredients, id: row.id)
                        )
                    }
                }

                Section("steps") {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, row in
                        numberedRow(
                            number: index + 1,
                            placeholder: NSLocalizedString("step", comment: ""),
                            text: rowBinding(in: $steps, id: row.id)
                        )
                    }
                }
            }
            .navigationTitle(editingRecipe == nil ? "new_recipe" : "edit_recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveRecipe()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func numberedRow(
        number: Int,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        HStack(spacing: 12) {
            Text("\(number).")
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)

            TextField(placeholder, text: text)
        }
    }

    private func rowBinding(
        in array: Binding<[TextRow]>,
        id: UUID
    ) -> Binding<String> {
        Binding<String>(
            get: {
                array.wrappedValue.first(where: { $0.id == id })?.text ?? ""
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

                guard let index = array.wrappedValue.firstIndex(where: { $0.id == id }) else {
                    return
                }

                array.wrappedValue[index].text = trimmed

                if index == array.wrappedValue.count - 1, !trimmed.isEmpty {
                    array.wrappedValue.append(TextRow(text: ""))
                }

                let nonEmpty = array.wrappedValue.filter {
                    !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }

                array.wrappedValue = nonEmpty + [TextRow(text: "")]
            }
        )
    }

    private func saveRecipe() {
        let cleanIngredients = ingredients
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let cleanSteps = steps
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let recipe = editingRecipe,
           let index = store.recipes.firstIndex(where: { $0.id == recipe.id }) {
            store.recipes[index] = Recipe(
                id: recipe.id,
                title: title,
                ingredients: cleanIngredients,
                steps: cleanSteps,
                isPinned: recipe.isPinned,
            )
        } else {
            store.recipes.append(
                Recipe(
                    title: title,
                    ingredients: cleanIngredients,
                    steps: cleanSteps
                )
            )
        }
    }
}
