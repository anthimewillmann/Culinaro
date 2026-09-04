import SwiftUI
import PhotosUI

struct AddItemView: View {
    enum ItemKind: CaseIterable, Identifiable {
        case recipe
        case lesson
        var id: Self { self }

        var localizedTitle: String {
            switch self {
            case .recipe:
                String(localized: "item_kind_recipe")
            case .lesson:
                String(localized: "item_kind_lesson")
            }
        }
    }

    @EnvironmentObject private var recipeStore: RecipeStore
    @EnvironmentObject private var lessonStore: LessonStore
    @EnvironmentObject private var statsStore: StatsStore
    @Environment(RecipeAIService.self) private var aiService
    @Environment(\.dismiss) private var dismiss

    private let editingRecipe: Recipe?
    private let editingLesson: Lesson?
    @State private var kind: ItemKind
    @State private var title: String
    @State private var ingredients: [TextRow]
    @State private var steps: [TextRow]
    @State private var generateEnabled: Bool
    @State private var tipsEnabled: Bool
    @State private var shouldRestoreTipsAfterLessonGeneration = false
    @State private var isApplyingAutomaticTipsChange = false
    @State private var calories: String
    @State private var proteinGrams: String
    @State private var carbsGrams: String
    @State private var fatGrams: String
    @State private var isGenerating = false
    @State private var isApplyingGeneratedContent = false
    @State private var generationTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var selectedPhoto: PhotosPickerItem?
    @FocusState private var isInputFocused: Bool

    init(editingRecipe: Recipe? = nil, editingLesson: Lesson? = nil, initialKind: ItemKind = .recipe) {
        self.editingRecipe = editingRecipe
        self.editingLesson = editingLesson
        let selectedKind: ItemKind = editingLesson == nil ? initialKind : .lesson
        _kind = State(initialValue: selectedKind)
        _title = State(initialValue: editingRecipe?.title ?? editingLesson?.title ?? "")
        // Fix: editingLesson.ingredients wurde vorher gar nicht gelesen.
        _ingredients = State(initialValue: (editingRecipe?.ingredients ?? editingLesson?.ingredients ?? []).map { TextRow(text: $0) } + [TextRow(text: "")])
        _steps = State(initialValue: (editingRecipe?.steps ?? editingLesson?.steps ?? []).map { TextRow(text: $0) } + [TextRow(text: "")])
        _generateEnabled = State(initialValue: editingRecipe?.wasGenerated ?? editingLesson?.wasGenerated ?? false)
        _tipsEnabled = State(initialValue: editingRecipe?.tipsEnabled ?? editingLesson?.tipsEnabled ?? true)
        let nutrition = editingRecipe?.nutrition ?? editingLesson?.nutrition
        _calories = State(initialValue: Self.optionalIntText(nutrition?.calories))
        _proteinGrams = State(initialValue: Self.optionalDoubleText(nutrition?.proteinGrams))
        _carbsGrams = State(initialValue: Self.optionalDoubleText(nutrition?.carbsGrams))
        _fatGrams = State(initialValue: Self.optionalDoubleText(nutrition?.fatGrams))
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("type", selection: $kind) {
                    ForEach(ItemKind.allCases) {
                        Text($0.localizedTitle).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(editingRecipe != nil || editingLesson != nil)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section("title") {
                    TextField(kind == .recipe ? String(localized: "recipe_title_placeholder") : String(localized: "lesson_title_placeholder"), text: manualBinding($title))
                        .focused($isInputFocused)
                }

                Section {
                    Toggle("generate_with_ai", isOn: focusDismissingBinding($generateEnabled))
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .onChange(of: generateEnabled) { _, enabled in
                            if enabled {
                                if kind == .lesson {
                                    shouldRestoreTipsAfterLessonGeneration = tipsEnabled
                                    isApplyingAutomaticTipsChange = true
                                    tipsEnabled = false
                                }
                                generateContent()
                            } else {
                                if kind == .lesson {
                                    if shouldRestoreTipsAfterLessonGeneration {
                                        tipsEnabled = true
                                    }
                                    shouldRestoreTipsAfterLessonGeneration = false
                                    isApplyingAutomaticTipsChange = false
                                }
                                cancelGenerationIfNeeded()
                            }
                        }
                    Toggle("generate_tips", isOn: focusDismissingBinding($tipsEnabled))
                        .onChange(of: tipsEnabled) { _, enabled in
                            guard kind == .lesson && generateEnabled else { return }

                            if isApplyingAutomaticTipsChange {
                                isApplyingAutomaticTipsChange = false
                            } else {
                                shouldRestoreTipsAfterLessonGeneration = enabled
                            }
                        }

                    Menu("scan_photo") {
                        Button("camera", systemImage: "camera") {
                            cancelGenerationIfNeeded()
                            showCamera = true
                        }
                        Button("photo_library", systemImage: "photo") {
                            cancelGenerationIfNeeded()
                            showGallery = true
                        }
                    }
                    if let errorMessage {
                        Text(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                }

                dynamicSection(title: "ingredients", placeholderTitle: String(localized: "ingredient"), rows: $ingredients, multiline: false)
                dynamicSection(title: "steps", placeholderTitle: String(localized: "step"), rows: $steps, multiline: true)
                nutritionSection
            }
            .navigationTitle(editingRecipe == nil && editingLesson == nil ? "new" : "edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        cancelGenerationIfNeeded()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .disabled(true)
                    } else {
                        Button {
                            cancelGenerationIfNeeded()
                            save()
                            dismiss()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                        .tint(.blue)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView { image in
                    showCamera = false
                    Task { await process(image) }
                }
            }
            .photosPicker(isPresented: $showGallery, selection: $selectedPhoto, matching: .images)
            .onChange(of: selectedPhoto) { _, item in
                cancelGenerationIfNeeded()
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    await process(image)
                }
            }
            .onChange(of: kind) { _, _ in
                cancelGenerationIfNeeded()
                resetDraft()
            }
        }
    }

    private var nutritionSection: some View {
        Section("nutrition") {
            nutritionTextField(String(localized: "calories"), text: $calories, keyboardType: .numberPad)
            nutritionTextField(String(localized: "protein"), text: $proteinGrams, keyboardType: .decimalPad)
            nutritionTextField(String(localized: "carbs"), text: $carbsGrams, keyboardType: .decimalPad)
            nutritionTextField(String(localized: "fat"), text: $fatGrams, keyboardType: .decimalPad)
        }
    }

    private func nutritionTextField(_ title: String, text: Binding<String>, keyboardType: UIKeyboardType) -> some View {
        HStack {
            TextField(title, text: manualBinding(text))
                .focused($isInputFocused)
                .keyboardType(keyboardType)

            if isGenerating {
                Spacer(minLength: 8)
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private func dynamicSection(title: String, placeholderTitle: String, rows: Binding<[TextRow]>, multiline: Bool) -> some View {
        Section(LocalizedStringKey(title)) {
            ForEach(Array(rows.wrappedValue.enumerated()), id: \.element.id) { index, row in
                HStack {
                    TextField(String.localizedStringWithFormat(String(localized: "indexed_field_placeholder"), index + 1, placeholderTitle), text: rowBinding(rows, index, id: row.id), axis: multiline ? .vertical : .horizontal)
                        .focused($isInputFocused)

                    if isGenerating && index == 0 {
                        Spacer(minLength: 8)
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    private func manualBinding(_ binding: Binding<String>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue },
            set: { value in
                guard value != binding.wrappedValue else { return }
                handleManualContentChange()
                binding.wrappedValue = value
            }
        )
    }

    private func focusDismissingBinding(_ binding: Binding<Bool>) -> Binding<Bool> {
        Binding(
            get: { binding.wrappedValue },
            set: { value in
                isInputFocused = false
                binding.wrappedValue = value
            }
        )
    }

    private func rowBinding(_ rows: Binding<[TextRow]>, _ index: Int, id: UUID) -> Binding<String> {
        Binding(
            get: { rows.wrappedValue[index].text },
            set: { value in
                guard value != rows.wrappedValue[index].text else { return }
                handleManualContentChange()
                updateRows(rows, index: index, value: value, id: id)
            }
        )
    }

    private func updateRows(_ rows: Binding<[TextRow]>, index: Int, value: String, id: UUID) {
        var array = rows.wrappedValue
        array[index].text = value
        let isEmpty: (TextRow) -> Bool = { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        if index == array.count - 1 && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            array.append(TextRow(text: ""))
        }

        // Die aktuell bearbeitete Zeile bleibt erhalten, auch wenn sie im Moment
        // leer ist (sonst verschwindet sie mitten in der Eingabe und der Fokus
        // geht verloren), ebenso die ursprünglich letzte Zeile (der Platzhalter
        // bleibt bestehen, auch wenn gerade eine andere Zeile leer ist). Ein
        // neuer Platzhalter wird nur angehängt, wenn danach keine leere Zeile
        // mehr am Ende steht — verhindert doppelte leere Zeilen, falls die
        // bearbeitete Zeile selbst zur letzten wird.
        let lastIndex = array.indices.last
        var compacted = array.enumerated()
            .filter { index, row in !isEmpty(row) || row.id == id || index == lastIndex }
            .map(\.element)
        if compacted.last.map(isEmpty) != true {
            compacted.append(TextRow(text: ""))
        }

        rows.wrappedValue = compacted
    }

    private func resetDraft() {
        generationTask?.cancel()
        generationTask = nil
        title = ""
        ingredients = [TextRow(text: "")]
        steps = [TextRow(text: "")]
        generateEnabled = false
        tipsEnabled = true
        shouldRestoreTipsAfterLessonGeneration = false
        isApplyingAutomaticTipsChange = false
        calories = ""
        proteinGrams = ""
        carbsGrams = ""
        fatGrams = ""
        isGenerating = false
        isApplyingGeneratedContent = false
        errorMessage = nil
        selectedPhoto = nil
        isInputFocused = false
    }

    private func handleManualContentChange() {
        guard !isApplyingGeneratedContent else { return }

        if isGenerating {
            cancelGenerationIfNeeded()
        } else if generateEnabled {
            generateEnabled = false
        }
    }

    private func cancelGenerationIfNeeded() {
        guard let generationTask, isGenerating else { return }
        generationTask.cancel()
        self.generationTask = nil
        isGenerating = false
        generateEnabled = false
    }

    private func clearFieldsForGeneration() {
        ingredients = [TextRow(text: "")]
        steps = [TextRow(text: "")]
        calories = ""
        proteinGrams = ""
        carbsGrams = ""
        fatGrams = ""
        isInputFocused = false
    }

    private func generateContent() {
        let prompt = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        generationTask?.cancel()
        clearFieldsForGeneration()
        isGenerating = true
        errorMessage = nil
        generationTask = Task {
            do {
                if kind == .recipe {
                    let parsed = try await aiService.generate(from: prompt, allergies: statsStore.allergies)
                    try Task.checkCancellation()
                    isApplyingGeneratedContent = true
                    defer { isApplyingGeneratedContent = false }
                    ingredients = parsed.ingredients.map { TextRow(text: $0) } + [TextRow(text: "")]
                    steps = parsed.steps.map { TextRow(text: $0) } + [TextRow(text: "")]
                    try await fillNutrition(title: prompt, ingredients: parsed.ingredients, steps: parsed.steps)
                } else {
                    let parsed = try await aiService.generateLesson(from: prompt)
                    try Task.checkCancellation()
                    isApplyingGeneratedContent = true
                    defer { isApplyingGeneratedContent = false }
                    ingredients = parsed.ingredients.map { TextRow(text: $0) } + [TextRow(text: "")]
                    steps = parsed.steps.map { TextRow(text: $0) } + [TextRow(text: "")]
                    try await fillNutrition(title: prompt, ingredients: parsed.ingredients, steps: parsed.steps)
                }
                isGenerating = false
                generationTask = nil
            } catch is CancellationError {
                isGenerating = false
                generationTask = nil
            } catch {
                // Match nutrition estimation behavior: keep the inline loading indicator visible if the model fails.
                errorMessage = nil
            }
        }
    }

    private func process(_ image: UIImage) async {
        isGenerating = true
        errorMessage = nil
        do {
            if kind == .recipe {
                let parsed = try await aiService.scan(image: image)
                title = parsed.title
                ingredients = parsed.ingredients.map { TextRow(text: $0) } + [TextRow(text: "")]
                steps = parsed.steps.map { TextRow(text: $0) } + [TextRow(text: "")]
                try await fillNutrition(title: parsed.title, ingredients: parsed.ingredients, steps: parsed.steps)
            } else {
                let parsed = try await aiService.scanLesson(image: image)
                title = parsed.title
                ingredients = parsed.ingredients.map { TextRow(text: $0) } + [TextRow(text: "")]
                steps = parsed.steps.map { TextRow(text: $0) } + [TextRow(text: "")]
                try await fillNutrition(title: parsed.title, ingredients: parsed.ingredients, steps: parsed.steps)
            }
            isGenerating = false
        } catch {
            // Match generation behavior: keep the inline loading indicator visible if scanning or nutrition estimation fails.
            errorMessage = nil
        }
    }

    private func cleaned(_ rows: [TextRow]) -> [String] {
        rows.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func fillNutrition(title: String, ingredients: [String], steps: [String]) async throws {
        let nutrition = try await nutritionInfo(title: title, ingredients: ingredients, steps: steps)
        calories = Self.optionalIntText(nutrition.calories)
        proteinGrams = Self.optionalDoubleText(nutrition.proteinGrams)
        carbsGrams = Self.optionalDoubleText(nutrition.carbsGrams)
        fatGrams = Self.optionalDoubleText(nutrition.fatGrams)
    }

    private func nutritionFromFields() -> NutritionInfo? {
        let caloriesValue = intValue(calories)
        let proteinValue = doubleValue(proteinGrams)
        let carbsValue = doubleValue(carbsGrams)
        let fatValue = doubleValue(fatGrams)
        guard caloriesValue != nil || proteinValue != nil || carbsValue != nil || fatValue != nil else { return nil }

        return NutritionInfo(
            calories: caloriesValue,
            proteinGrams: proteinValue,
            carbsGrams: carbsValue,
            fatGrams: fatValue,
            servings: existingNutritionServings
        )
    }

    private var existingNutritionServings: Int {
        (editingRecipe?.nutrition ?? editingLesson?.nutrition)?.servings ?? 1
    }

    private func intValue(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func doubleValue(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private static func optionalIntText(_ value: Int?) -> String {
        value.map(String.init) ?? ""
    }

    private static func optionalDoubleText(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func save() {
        if kind == .recipe {
            let recipeIngredients = cleaned(ingredients)
            let recipe = Recipe(
                id: editingRecipe?.id ?? UUID(),
                title: title,
                ingredients: recipeIngredients,
                steps: cleaned(steps),
                isPinned: editingRecipe?.isPinned ?? false,
                tipsEnabled: tipsEnabled,
                wasGenerated: generateEnabled,
                nutrition: nutritionFromFields() ?? retainedNutrition(forIngredients: recipeIngredients),
                createdAt: editingRecipe?.createdAt ?? Date()
            )
            recipeStore.save(recipe, editing: editingRecipe)
            estimateNutritionInBackground(for: recipe)
        } else {
            // Fix: ingredients wurde hier vorher gar nicht mitgegeben.
            lessonStore.save(Lesson(title: title, ingredients: cleaned(ingredients), steps: cleaned(steps), wasGenerated: generateEnabled, tipsEnabled: tipsEnabled, nutrition: nutritionFromFields()), editing: editingLesson)
        }
    }

    private func retainedNutrition(forIngredients ingredients: [String]) -> NutritionInfo? {
        guard let editingRecipe else { return nil }
        return editingRecipe.ingredients == ingredients ? editingRecipe.nutrition : nil
    }

    private func estimateNutritionInBackground(for recipe: Recipe) {
        guard recipe.nutrition == nil, !recipe.ingredients.isEmpty else { return }

        Task {
            do {
                let nutrition = try await nutritionInfo(title: recipe.title, ingredients: recipe.ingredients)
                let updatedRecipe = Recipe(
                    id: recipe.id,
                    title: recipe.title,
                    ingredients: recipe.ingredients,
                    steps: recipe.steps,
                    isPinned: recipe.isPinned,
                    tipsEnabled: recipe.tipsEnabled,
                    wasGenerated: recipe.wasGenerated,
                    nutrition: nutrition,
                    createdAt: recipe.createdAt
                )
                await MainActor.run {
                    recipeStore.save(updatedRecipe, editing: updatedRecipe)
                }
            } catch {
                // Nutrition is helpful metadata, so recipe creation should not fail if estimation is unavailable.
            }
        }
    }

    private func nutritionInfo(title: String, ingredients: [String], steps: [String] = []) async throws -> NutritionInfo {
        let estimate = try await aiService.estimateNutrition(title: title, ingredients: ingredients, steps: steps)
        return NutritionInfo(
            calories: estimate.calories,
            proteinGrams: estimate.protein,
            carbsGrams: estimate.carbs,
            fatGrams: estimate.fat,
            servings: max(estimate.servings, 1)
        )
    }
}
