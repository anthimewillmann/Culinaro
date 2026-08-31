import SwiftUI
import PhotosUI

struct HealthView: View {
    @EnvironmentObject private var nutrition: NutritionStore

    var body: some View {
        Form {
            Section("today") {
                nutritionField(String(localized: "calories"), formattedWholeNumber(Double(nutrition.caloriesToday)))
                nutritionField(String(localized: "protein"), formattedDecimal(nutrition.proteinToday))
                nutritionField(String(localized: "carbs"), formattedDecimal(nutrition.carbsToday))
                nutritionField(String(localized: "fat"), formattedDecimal(nutrition.fatToday))
            }

            Section("average_last_7_days") {
                let average = nutrition.averageLastSevenDays
                nutritionField(String(localized: "calories"), formattedWholeNumber(average.calories))
                nutritionField(String(localized: "protein"), formattedDecimal(average.proteinGrams))
                nutritionField(String(localized: "carbs"), formattedDecimal(average.carbsGrams))
                nutritionField(String(localized: "fat"), formattedDecimal(average.fatGrams))
            }

            Section("average_last_30_days") {
                let average = nutrition.averageLastThirtyDays
                nutritionField(String(localized: "calories"), formattedWholeNumber(average.calories))
            }
        }
        .scrollContentBackground(.hidden)
        .background(ManagedAnimationBackgroundView())
        .containerBackground(.clear, for: .navigation)
        .navigationTitle("nutrition")
    }

    private func nutritionField(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
    }

    private func formattedWholeNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    private func formattedDecimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

struct AddHealthRecipeSheet: View {
    @EnvironmentObject private var nutrition: NutritionStore
    @Environment(RecipeAIService.self) private var aiService
    @Environment(\.dismiss) private var dismiss

    var initialDate: Date = Date()

    @State private var ingredients = [TextRow(text: "")]
    @State private var generateNutritionWithAI = false
    @State private var calories = ""
    @State private var proteinGrams = ""
    @State private var carbsGrams = ""
    @State private var fatGrams = ""
    @State private var isProcessing = false
    @State private var isScanningFood = false
    @State private var generationTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var selectedPhoto: PhotosPickerItem?
    @FocusState private var focusedField: UUID?

    private var recipeTitle: String {
        cleanedIngredients.first ?? String(localized: "food")
    }

    private var cleanedIngredients: [String] {
        ingredients
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var hasManualNutrition: Bool {
        nutritionFromFields() != nil
    }

    private var canGenerateNutrition: Bool {
        generateNutritionWithAI && !cleanedIngredients.isEmpty
    }

    private var canSave: Bool {
        !isProcessing && (hasManualNutrition || canGenerateNutrition)
    }

    var body: some View {
        NavigationStack {
            Form {
                dynamicSection(title: "ingredients", placeholderTitle: String(localized: "ingredient"), rows: $ingredients)

                Section {
                    Toggle("generate_with_ai", isOn: $generateNutritionWithAI)
                        .disabled(cleanedIngredients.isEmpty)
                        .onChange(of: generateNutritionWithAI) { _, isEnabled in
                            guard isEnabled else {
                                cancelGenerationIfNeeded()
                                return
                            }
                            generateNutrition()
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
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                nutritionSection
            }
            .navigationTitle("add_food")
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
                    if canSave {
                        Button {
                            save()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                        .tint(.blue)
                    } else {
                        Button {
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .disabled(true)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView { image in
                    showCamera = false
                    process(image)
                }
            }
            .photosPicker(isPresented: $showGallery, selection: $selectedPhoto, matching: .images)
            .onChange(of: selectedPhoto) { _, item in
                cancelGenerationIfNeeded()
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    process(image)
                }
            }
            .onAppear { focusedField = ingredients.first?.id }
        }
    }

    private var nutritionSection: some View {
        Section("nutrition_facts") {
            nutritionTextField(String(localized: "calories"), text: $calories, keyboardType: .numberPad)
            nutritionTextField(String(localized: "protein"), text: $proteinGrams, keyboardType: .decimalPad)
            nutritionTextField(String(localized: "carbs"), text: $carbsGrams, keyboardType: .decimalPad)
            nutritionTextField(String(localized: "fat"), text: $fatGrams, keyboardType: .decimalPad)
        }
    }

    private func nutritionTextField(_ title: String, text: Binding<String>, keyboardType: UIKeyboardType) -> some View {
        HStack {
            TextField(title, text: text)
                .keyboardType(keyboardType)

            if isProcessing {
                Spacer(minLength: 8)
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private func dynamicSection(title: String, placeholderTitle: String, rows: Binding<[TextRow]>) -> some View {
        Section(LocalizedStringKey(title)) {
            ForEach(Array(rows.wrappedValue.enumerated()), id: \.element.id) { index, row in
                HStack {
                    TextField(String.localizedStringWithFormat(String(localized: "indexed_field_placeholder"), index + 1, placeholderTitle), text: rowBinding(rows, index))
                        .focused($focusedField, equals: row.id)
                        .onChange(of: rows.wrappedValue[index].text) { _, value in
                            cancelGenerationIfNeeded()
                            updateRows(rows, index: index, value: value, id: row.id)
                        }

                    if isScanningFood && index == 0 {
                        Spacer(minLength: 8)
                        ProgressView()
                            .controlSize(.small)
                    }
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
        if compacted.allSatisfy({ $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            generateNutritionWithAI = false
        }
        focusedField = compacted.contains { $0.id == id } ? id : nil
    }

    private func process(_ image: UIImage) {
        generationTask?.cancel()
        isProcessing = true
        isScanningFood = true
        errorMessage = nil
        generationTask = Task {
            do {
                let parsed = try await aiService.scan(image: image)
                try Task.checkCancellation()

                let newIngredients = appendGeneratedIngredients(parsed.ingredients)
                guard !newIngredients.isEmpty else { return }

                let estimate = try await aiService.estimateNutrition(
                    title: parsed.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? newIngredients[0] : parsed.title,
                    ingredients: newIngredients,
                    steps: parsed.steps
                )
                try Task.checkCancellation()

                addNutritionEstimate(estimate)
                isProcessing = false
                isScanningFood = false
                generationTask = nil
            } catch is CancellationError {
                isProcessing = false
                isScanningFood = false
                generationTask = nil
            } catch {
                // Match recipe/lesson generation: keep the inline loading indicator visible when scanning/generation fails.
                errorMessage = nil
            }
        }
    }

    private func cancelGenerationIfNeeded() {
        guard generationTask != nil, isProcessing else { return }
        generationTask?.cancel()
        generationTask = nil
        isProcessing = false
        isScanningFood = false
        generateNutritionWithAI = false
    }

    private func generateNutrition() {
        guard !cleanedIngredients.isEmpty else { return }
        generationTask?.cancel()
        isProcessing = true
        errorMessage = nil
        generationTask = Task {
            do {
                try await fillNutritionFromIngredients()
                try Task.checkCancellation()
                isProcessing = false
                generationTask = nil
            } catch is CancellationError {
                isProcessing = false
                generationTask = nil
            } catch {
                // Match recipe/lesson generation: keep the inline loading indicator visible when generation fails.
                errorMessage = nil
            }
        }
    }

    private func fillNutritionFromIngredients() async throws {
        let estimate = try await aiService.estimateNutrition(title: recipeTitle, ingredients: cleanedIngredients)
        addNutritionEstimate(estimate)
    }

    private func appendGeneratedIngredients(_ generatedIngredients: [String]) -> [String] {
        let existingValues = cleanedIngredients
        let newValues = generatedIngredients
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !newValues.isEmpty else { return [] }
        ingredients = (existingValues + newValues).map { TextRow(text: $0) } + [TextRow(text: "")]
        focusedField = ingredients.last?.id
        return newValues
    }

    private func addNutritionEstimate(_ estimate: NutritionEstimate) {
        let updatedCalories = (intValue(calories) ?? 0) + estimate.calories
        let updatedProtein = (doubleValue(proteinGrams) ?? 0) + estimate.protein
        let updatedCarbs = (doubleValue(carbsGrams) ?? 0) + estimate.carbs
        let updatedFat = (doubleValue(fatGrams) ?? 0) + estimate.fat

        calories = String(updatedCalories)
        proteinGrams = formattedDecimal(updatedProtein)
        carbsGrams = formattedDecimal(updatedCarbs)
        fatGrams = formattedDecimal(updatedFat)
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
            servings: 1
        )
    }

    private func intValue(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func doubleValue(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func formattedDecimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func save() {
        if let manualNutrition = nutritionFromFields() {
            logMeal(with: manualNutrition)
            dismiss()
            return
        }

        Task {
            isProcessing = true
            errorMessage = nil
            do {
                let estimate = try await aiService.estimateNutrition(title: recipeTitle, ingredients: cleanedIngredients)
                await MainActor.run {
                    logMeal(with: NutritionInfo(
                        calories: estimate.calories,
                        proteinGrams: estimate.protein,
                        carbsGrams: estimate.carbs,
                        fatGrams: estimate.fat,
                        servings: max(estimate.servings, 1)
                    ))
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }

    private func logMeal(with nutritionInfo: NutritionInfo) {
        let recipe = Recipe(
            title: recipeTitle,
            ingredients: cleanedIngredients,
            steps: [],
            nutrition: nutritionInfo
        )
        nutrition.logMeal(recipe: recipe, servings: 1, loggedAt: initialDate)
    }
}
