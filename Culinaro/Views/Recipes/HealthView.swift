import SwiftUI
import PhotosUI

struct HealthView: View {
    @EnvironmentObject private var nutrition: NutritionStore

    var body: some View {
        Form {
            Section("Heute") {
                nutritionField("Kalorien", formattedWholeNumber(Double(nutrition.caloriesToday)))
                nutritionField("Protein", formattedDecimal(nutrition.proteinToday))
                nutritionField("Kohlenhydrate", formattedDecimal(nutrition.carbsToday))
                nutritionField("Fett", formattedDecimal(nutrition.fatToday))
            }

            Section("Durchschnitt der letzten 7 Tage") {
                let average = nutrition.averageLastSevenDays
                nutritionField("Kalorien", formattedWholeNumber(average.calories))
                nutritionField("Protein", formattedDecimal(average.proteinGrams))
                nutritionField("Kohlenhydrate", formattedDecimal(average.carbsGrams))
                nutritionField("Fett", formattedDecimal(average.fatGrams))
            }

            Section("Durchschnitt der letzten 30 Tage") {
                let average = nutrition.averageLastThirtyDays
                nutritionField("Kalorien", formattedWholeNumber(average.calories))
            }
        }
        .navigationTitle("Ernährung")
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

    @State private var title = ""
    @State private var ingredients = [TextRow(text: "")]
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var selectedPhoto: PhotosPickerItem?
    @FocusState private var focusedField: UUID?

    private var recipeTitle: String {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedTitle.isEmpty ? "Rezept" : cleanedTitle
    }

    private var cleanedIngredients: [String] {
        ingredients
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !cleanedIngredients.isEmpty && !isProcessing
    }

    var body: some View {
        NavigationStack {
            Form {
                dynamicSection(title: "Zutaten", placeholderTitle: "Zutat", rows: $ingredients)

                Section("Scannen") {
                    Menu("Rezept scannen") {
                        Button("Kamera", systemImage: "camera") { showCamera = true }
                        Button("Fotomediathek", systemImage: "photo") { showGallery = true }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .disabled(isProcessing)
            .overlay {
                if isProcessing {
                    ProgressView("Wird analysiert ...")
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 12))
                }
            }
            .navigationTitle("Rezept hinzufügen")
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
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(!canSave)
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
            .onAppear { focusedField = ingredients.first?.id }
        }
    }

    @ViewBuilder
    private func dynamicSection(title: String, placeholderTitle: String, rows: Binding<[TextRow]>) -> some View {
        Section(title) {
            ForEach(Array(rows.wrappedValue.enumerated()), id: \.element.id) { index, row in
                TextField("\(index + 1). \(placeholderTitle)", text: rowBinding(rows, index))
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

    private func process(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil
        do {
            let parsed = try await aiService.scan(image: image)
            title = parsed.title
            ingredients = parsed.ingredients.map { TextRow(text: $0) } + [TextRow(text: "")]
            isProcessing = false
        } catch {
            errorMessage = error.localizedDescription
            isProcessing = false
        }
    }

    private func save() {
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                let estimate = try await aiService.estimateNutrition(title: recipeTitle, ingredients: cleanedIngredients)
                let recipe = Recipe(
                    title: recipeTitle,
                    ingredients: cleanedIngredients,
                    steps: [],
                    nutrition: NutritionInfo(
                        calories: estimate.calories,
                        proteinGrams: estimate.protein,
                        carbsGrams: estimate.carbs,
                        fatGrams: estimate.fat,
                        servings: max(estimate.servings, 1)
                    )
                )
                await MainActor.run {
                    nutrition.logMeal(recipe: recipe, servings: 1)
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
}
