import SwiftUI
import PhotosUI

struct AddRecipeView: View {
    @EnvironmentObject var store: RecipeStore
    @Environment(\.dismiss) private var dismiss
    @Environment(RecipeAIService.self) private var aiService

    var editingRecipe: Recipe? = nil

    @State private var title: String = ""
    @State private var ingredients: [TextRow] = [TextRow(text: "")]
    @State private var steps: [TextRow] = [TextRow(text: "")]

    @State private var generateEnabled: Bool = false
    @State private var tipsEnabled: Bool = true
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String? = nil

    @State private var showCamera: Bool = false
    @State private var showGallery: Bool = false
    @State private var selectedPhoto: PhotosPickerItem? = nil

    init(editingRecipe: Recipe? = nil) {
        self.editingRecipe = editingRecipe
        if let recipe = editingRecipe {
            _title = State(initialValue: recipe.title)
            _ingredients = State(initialValue: recipe.ingredients.map { TextRow(text: $0) } + [TextRow(text: "")])
            _steps = State(initialValue: recipe.steps.map { TextRow(text: $0) } + [TextRow(text: "")])
            _tipsEnabled = State(initialValue: recipe.tipsEnabled)
            _generateEnabled = State(initialValue: recipe.wasGenerated)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: – Title
                Section {
                    TextField(NSLocalizedString("recipe_title_placeholder", comment: ""), text: $title)
                }

                // MARK: – Generate / Tips / Scanner
                Section {
                    Toggle(NSLocalizedString("ai_generate_button", comment: "Generate"), isOn: $generateEnabled)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating)
                        .onChange(of: generateEnabled) { _, enabled in
                            if enabled {
                                generateRecipeFromTitle()
                            } else {
                                if editingRecipe == nil {
                                    ingredients = [TextRow(text: "")]
                                    steps = [TextRow(text: "")]
                                }
                                errorMessage = nil
                            }
                        }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Toggle(NSLocalizedString("tips_toggle_label", comment: "Tips"), isOn: $tipsEnabled)

                    Menu {
                        Button {
                            showCamera = true
                        } label: {
                            Label(NSLocalizedString("scanner_take_photo", comment: ""), systemImage: "camera")
                        }

                        Button {
                            showGallery = true
                        } label: {
                            Label(NSLocalizedString("scanner_from_gallery", comment: ""), systemImage: "photo")
                        }
                    } label: {
                        Text(NSLocalizedString("scanner_add_photo", comment: ""))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .tint(.primary)
                }

                // MARK: – Ingredients
                Section {
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(Array(ingredients.enumerated()), id: \.element.id) { index, row in
                            TextField(
                                index == 0
                                    ? NSLocalizedString("ingredients_header", comment: "Ingredients")
                                    : NSLocalizedString("ingredient", comment: "Ingredient"),
                                text: rowBinding(in: $ingredients, id: row.id)
                            )
                        }
                    }
                }

                // MARK: – Steps
                Section {
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, row in
                            TextField(
                                index == 0
                                    ? NSLocalizedString("steps_header", comment: "Steps")
                                    : NSLocalizedString("step", comment: "Step"),
                                text: rowBinding(in: $steps, id: row.id),
                                axis: .vertical
                            )
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString(editingRecipe == nil ? "nav_title_new" : "nav_title_edit", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.medium)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveRecipe()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .fontWeight(.medium)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView { image in
                    showCamera = false
                    Task { await processImage(image) }
                }
            }
            .sheet(isPresented: $showGallery) {
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images
                ) {
                    Text(NSLocalizedString("scanner_from_gallery", comment: ""))
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    showGallery = false
                    Task {
                        guard let data = try? await newItem?.loadTransferable(type: Data.self),
                              let image = UIImage(data: data) else { return }
                        await processImage(image)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: – Image Processing

    private func processImage(_ image: UIImage) async {
        await MainActor.run { errorMessage = nil }
        do {
            let parsed = try await aiService.scan(image: image)
            await MainActor.run {
                title = parsed.title
                ingredients = parsed.ingredients.map { TextRow(text: $0) } + [TextRow(text: "")]
                steps = parsed.steps.map { TextRow(text: $0) } + [TextRow(text: "")]
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: – AI Generation

    private func generateRecipeFromTitle() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { generateEnabled = false; return }
        isGenerating = true
        errorMessage = nil
        ingredients = [TextRow(text: "")]
        steps = [TextRow(text: "")]

        Task {
            do {
                let parsed = try await aiService.generate(from: trimmed)
                await MainActor.run {
                    ingredients = parsed.ingredients.map { TextRow(text: $0) } + [TextRow(text: "")]
                    steps = parsed.steps.map { TextRow(text: $0) } + [TextRow(text: "")]
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGenerating = false
                    generateEnabled = false
                }
            }
        }
    }

    // MARK: – Row Binding

    private func rowBinding(in array: Binding<[TextRow]>, id: UUID) -> Binding<String> {
        Binding<String>(
            get: { array.wrappedValue.first(where: { $0.id == id })?.text ?? "" },
            set: { newValue in
                guard let index = array.wrappedValue.firstIndex(where: { $0.id == id }) else { return }
                array.wrappedValue[index].text = newValue

                if index == array.wrappedValue.count - 1 && !newValue.isEmpty {
                    array.wrappedValue.append(TextRow(text: ""))
                }

                let nonEmpty = array.wrappedValue.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                array.wrappedValue = nonEmpty + [TextRow(text: "")]
            }
        )
    }

    // MARK: – Save

    private func saveRecipe() {
        let cleanIngredients = ingredients
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let cleanSteps = steps
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        store.save(
            Recipe(title: title, ingredients: cleanIngredients, steps: cleanSteps, tipsEnabled: tipsEnabled, wasGenerated: generateEnabled),
            editing: editingRecipe
        )
    }
}
