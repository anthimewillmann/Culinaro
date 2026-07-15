import SwiftUI
import PhotosUI

struct AddItemView: View {
    enum ItemKind: String, CaseIterable, Identifiable {
        case recipe = "Rezept"
        case lesson = "Lektion"
        var id: Self { self }
    }

    @EnvironmentObject private var recipeStore: RecipeStore
    @EnvironmentObject private var lessonStore: LessonStore
    @EnvironmentObject private var statsStore: StatsStore
    @Environment(RecipeAIService.self) private var aiService
    @Environment(\.dismiss) private var dismiss

    private let editingRecipe: Recipe?
    private let editingLesson: Lesson?
    private var tipsToggleDisabled: Bool { kind == .lesson && generateEnabled }
    @State private var kind: ItemKind
    @State private var title: String
    @State private var ingredients: [TextRow]
    @State private var steps: [TextRow]
    @State private var generateEnabled: Bool
    @State private var tipsEnabled: Bool
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var selectedPhoto: PhotosPickerItem?
    @FocusState private var focusedField: UUID?

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
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Typ", selection: $kind) {
                    ForEach(ItemKind.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(editingRecipe != nil || editingLesson != nil)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section("Titel") {
                    TextField(kind == .recipe ? "Rezepttitel" : "Lektionstitel", text: $title)
                }

                Section {
                    Toggle("Mit KI generieren", isOn: $generateEnabled)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                        .onChange(of: generateEnabled) { _, enabled in
                            if kind == .lesson && enabled {
                                tipsEnabled = false
                            }
                            if enabled { generateContent() }
                        }
                    Toggle("Tipps im Kochmodus", isOn: $tipsEnabled)
                        .disabled(tipsToggleDisabled)
                        .opacity(tipsToggleDisabled ? 0.45 : 1)

                    Menu("Foto scannen") {
                        Button("Kamera", systemImage: "camera") { showCamera = true }
                        Button("Fotomediathek", systemImage: "photo") { showGallery = true }
                    }
                    if let errorMessage {
                        Text(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                }

                dynamicSection(title: "Zutaten", placeholderTitle: "Zutat", rows: $ingredients, multiline: false)
                dynamicSection(title: "Schritte", placeholderTitle: "Schritt", rows: $steps, multiline: true)
            }
            .disabled(isGenerating)
            .overlay { if isGenerating { ProgressView("Wird erstellt …").padding().background(.regularMaterial, in: .rect(cornerRadius: 12)) } }
            .navigationTitle(editingRecipe == nil && editingLesson == nil ? "Neu" : "Bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    await process(image)
                }
            }
            .onChange(of: kind) { _, _ in
                resetDraft()
            }
        }
    }

    @ViewBuilder
    private func dynamicSection(title: String, placeholderTitle: String, rows: Binding<[TextRow]>, multiline: Bool) -> some View {
        Section(title) {
            ForEach(Array(rows.wrappedValue.enumerated()), id: \.element.id) { index, row in
                TextField("\(index + 1). \(placeholderTitle)", text: rowBinding(rows, index), axis: multiline ? .vertical : .horizontal)
                    .focused($focusedField, equals: row.id)
                    .onChange(of: rows.wrappedValue[index].text) { _, value in
                        updateRows(rows, index: index, value: value, id: row.id)
                    }
            }
        }
    }

    private func rowBinding(_ rows: Binding<[TextRow]>, _ index: Int) -> Binding<String> {
        Binding(get: { rows.wrappedValue[index].text }, set: { rows.wrappedValue[index].text = $0 })
    }

    private func updateRows(_ rows: Binding<[TextRow]>, index: Int, value: String, id: UUID) {
        var array = rows.wrappedValue
        let isEmpty: (TextRow) -> Bool = { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        if index == array.count - 1 && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            array.append(TextRow(text: ""))
        }

        let trailingPlaceholder = array.last.flatMap { isEmpty($0) ? $0 : nil }
        var compacted = array.filter { !isEmpty($0) }
        compacted.append(trailingPlaceholder ?? TextRow(text: ""))

        rows.wrappedValue = compacted
        focusedField = compacted.contains { $0.id == id } ? id : nil
    }

    private func resetDraft() {
        title = ""
        ingredients = [TextRow(text: "")]
        steps = [TextRow(text: "")]
        generateEnabled = false
        tipsEnabled = true
        errorMessage = nil
        selectedPhoto = nil
        focusedField = nil
    }

    private func generateContent() {
        let prompt = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        isGenerating = true
        errorMessage = nil
        Task {
            do {
                if kind == .recipe {
                    let parsed = try await aiService.generate(from: prompt, allergies: statsStore.allergies)
                    title = parsed.title
                    ingredients = parsed.ingredients.map { TextRow(text: $0) } + [TextRow(text: "")]
                    steps = parsed.steps.map { TextRow(text: $0) } + [TextRow(text: "")]
                } else {
                    let parsed = try await aiService.generateLesson(from: prompt)
                    title = parsed.title
                    steps = parsed.steps.map { TextRow(text: $0) } + [TextRow(text: "")]
                }
                isGenerating = false
            } catch {
                errorMessage = error.localizedDescription
                isGenerating = false
                generateEnabled = false
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
            } else {
                let parsed = try await aiService.scanLesson(image: image)
                title = parsed.title
                steps = parsed.steps.map { TextRow(text: $0) } + [TextRow(text: "")]
            }
            isGenerating = false
        } catch {
            errorMessage = error.localizedDescription
            isGenerating = false
        }
    }

    private func cleaned(_ rows: [TextRow]) -> [String] {
        rows.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
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
                nutrition: retainedNutrition(forTitle: title, ingredients: recipeIngredients),
                createdAt: editingRecipe?.createdAt ?? Date()
            )
            recipeStore.save(recipe, editing: editingRecipe)
            estimateNutritionInBackground(for: recipe)
        } else {
            // Fix: ingredients wurde hier vorher gar nicht mitgegeben.
            lessonStore.save(Lesson(title: title, ingredients: cleaned(ingredients), steps: cleaned(steps), wasGenerated: generateEnabled, tipsEnabled: tipsEnabled), editing: editingLesson)
        }
    }

    private func retainedNutrition(forTitle title: String, ingredients: [String]) -> NutritionInfo? {
        guard let editingRecipe else { return nil }

        let titleMatches = editingRecipe.title.trimmingCharacters(in: .whitespacesAndNewlines) == title.trimmingCharacters(in: .whitespacesAndNewlines)
        let ingredientsMatch = editingRecipe.ingredients == ingredients
        return titleMatches && ingredientsMatch ? editingRecipe.nutrition : nil
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

    private func nutritionInfo(title: String, ingredients: [String]) async throws -> NutritionInfo {
        let estimate = try await aiService.estimateNutrition(title: title, ingredients: ingredients)
        return NutritionInfo(
            calories: estimate.calories,
            proteinGrams: estimate.protein,
            carbsGrams: estimate.carbs,
            fatGrams: estimate.fat,
            servings: max(estimate.servings, 1)
        )
    }
}
