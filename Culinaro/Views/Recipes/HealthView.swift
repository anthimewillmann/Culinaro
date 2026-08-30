import SwiftUI
import PhotosUI

struct HealthView: View {
    @EnvironmentObject private var nutrition: NutritionStore
    @State private var isShowingHistory = false

    var body: some View {
        Form {
            Section("today") {
                let fields = [
                    (String(localized: "calories"), formattedWholeNumber(Double(nutrition.caloriesToday))),
                    (String(localized: "protein"), formattedDecimal(nutrition.proteinToday)),
                    (String(localized: "carbs"), formattedDecimal(nutrition.carbsToday)),
                    (String(localized: "fat"), formattedDecimal(nutrition.fatToday))
                ]

                ForEach(Array(fields.enumerated()), id: \.offset) { index, field in
                    nutritionField(field.0, field.1)
                        .listRowBackground(CulinaroFieldBackground(position: .forIndex(index, count: fields.count)))
                }
            }
            .meadowRowBackground()

            Section("average_last_7_days") {
                let average = nutrition.averageLastSevenDays
                let fields = [
                    (String(localized: "calories"), formattedWholeNumber(average.calories)),
                    (String(localized: "protein"), formattedDecimal(average.proteinGrams)),
                    (String(localized: "carbs"), formattedDecimal(average.carbsGrams)),
                    (String(localized: "fat"), formattedDecimal(average.fatGrams))
                ]

                ForEach(Array(fields.enumerated()), id: \.offset) { index, field in
                    nutritionField(field.0, field.1)
                        .listRowBackground(CulinaroFieldBackground(position: .forIndex(index, count: fields.count)))
                }
            }
            .meadowRowBackground()

            Section("average_last_30_days") {
                let average = nutrition.averageLastThirtyDays
                nutritionField(String(localized: "calories"), formattedWholeNumber(average.calories))
                    .listRowBackground(CulinaroFieldBackground())
            }

            Section("history") {
                Button {
                    isShowingHistory = true
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("health_history")
                        Text(historyCountText(nutrition.recentLoggedMeals.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(CulinaroFieldBackground())
            }
            .meadowRowBackground()

            Section {
                NavigationLink {
                    HealthHistoryView()
                } label: {
                    Label("history", systemImage: "clock.arrow.circlepath")
                }
            }
            .meadowRowBackground()
        }
        .scrollContentBackground(.hidden)
        // Die animierte Wiese sitzt direkt hinter dem Formular, innerhalb
        // derselben View-Hierarchie — nicht mehr als externes Fenster
        // hinter der ganzen App. `.allowsHitTesting(false)` verhindert,
        // dass die Wiese selbst jemals Touches abbekommt.
        .culinaroMeadowBackground()
        .containerBackground(.clear, for: .navigation)
        .syncErrorBanner(nutrition.syncError)
        .navigationTitle("nutrition")
<<<<<<< HEAD
        .navigationDestination(isPresented: $isShowingHistory) {
            HealthHistoryView()
        }
=======
        .refreshable { await nutrition.syncFromCloud() }
>>>>>>> main
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

    private func historyCountText(_ count: Int) -> String {
        if count == 1 {
            String(localized: "one_history_entry")
        } else {
            String.localizedStringWithFormat(String(localized: "history_entries_count"), count)
        }
    }

    private func formattedWholeNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    private func formattedDecimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

private struct HealthHistoryView: View {
    @EnvironmentObject private var nutrition: NutritionStore
    @State private var addMealDaysAgo: Int?

    private var groups: [(daysAgo: Int, meals: [LoggedMeal])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let grouped = Dictionary(grouping: nutrition.recentLoggedMeals) { meal in
            let mealDay = calendar.startOfDay(for: meal.loggedAt)
            return calendar.dateComponents([.day], from: mealDay, to: today).day ?? 0
        }

        return grouped.keys.sorted().map { daysAgo in
            (daysAgo, grouped[daysAgo, default: []].sorted { $0.loggedAt > $1.loggedAt })
        }
    }

    var body: some View {
        List {
            ForEach(groups, id: \.daysAgo) { group in
                Section {
                    let rowCount = group.meals.count + 1
                    ForEach(Array(group.meals.enumerated()), id: \.element.id) { index, meal in
                        NavigationLink {
                            MealNutritionDetailView(meal: meal)
                        } label: {
                            mealRow(for: meal)
                        }
                        .listRowBackground(CulinaroFieldBackground(position: .forIndex(index, count: rowCount)))
                    }

                    Button {
                        addMealDaysAgo = group.daysAgo
                    } label: {
                        Label("add_food", systemImage: "plus")
                    }
                    .listRowBackground(CulinaroFieldBackground(position: .forIndex(rowCount - 1, count: rowCount)))
                } header: {
                    Text(dayHeader(for: group.daysAgo))
                }
            }
        }
        .overlay {
            if groups.isEmpty {
                ContentUnavailableView("no_recent_meals", systemImage: "clock.arrow.circlepath")
            }
        }
        .scrollContentBackground(.hidden)
        .culinaroMeadowBackground()
        .containerBackground(.clear, for: .navigation)
        .navigationTitle("health_history")
        .sheet(isPresented: Binding(
            get: { addMealDaysAgo != nil },
            set: { isPresented in
                if !isPresented { addMealDaysAgo = nil }
            }
        )) {
            AddHealthRecipeSheet(loggedAt: logDate(for: addMealDaysAgo ?? 0))
        }
    }

    private func logDate(for daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
    }

    private func dayHeader(for daysAgo: Int) -> String {
        if daysAgo == 1 {
            String(localized: "one_day_ago")
        } else {
            String.localizedStringWithFormat(String(localized: "days_ago"), daysAgo)
        }
    }

    private func mealRow(for meal: LoggedMeal) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.recipeTitle)
                    .fontWeight(.semibold)
                Text(meal.loggedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(meal.calories, format: .number)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MealNutritionDetailView: View {
    let meal: LoggedMeal

    var body: some View {
        Form {
            Section("nutrition_facts") {
                let fields = [
                    (String(localized: "calories"), meal.calories.formatted(.number)),
                    (String(localized: "protein"), gramsText(meal.proteinGrams)),
                    (String(localized: "carbs"), gramsText(meal.carbsGrams)),
                    (String(localized: "fat"), gramsText(meal.fatGrams))
                ]

                ForEach(Array(fields.enumerated()), id: \.offset) { index, field in
                    LabeledContent(field.0, value: field.1)
                        .listRowBackground(CulinaroFieldBackground(position: .forIndex(index, count: fields.count)))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .culinaroMeadowBackground()
        .containerBackground(.clear, for: .navigation)
        .navigationTitle(meal.recipeTitle)
    }

    private func gramsText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)))) g"
    }
}

struct AddHealthRecipeSheet: View {
    let loggedAt: Date

    @EnvironmentObject private var nutrition: NutritionStore
    @Environment(RecipeAIService.self) private var aiService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date
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

<<<<<<< HEAD
    init(loggedAt: Date = Date()) {
        self.loggedAt = loggedAt
=======
    init(initialDate: Date = Date()) {
        _selectedDate = State(initialValue: initialDate)
>>>>>>> main
    }

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
            DatePicker("date", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
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
        if compacted.allSatisfy({ $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            generateNutritionWithAI = false
        }
        focusedField = id
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
                guard !newIngredients.isEmpty else {
                    isProcessing = false
                    isScanningFood = false
                    generationTask = nil
                    return
                }

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
        // Cancellation must be checked BEFORE writing the estimate back —
        // otherwise a stale result from an already-cancelled generation
        // (e.g. the user edited the ingredients while the AI call was still
        // in flight) still overwrites the fields after the fact.
        try Task.checkCancellation()
        setNutritionEstimate(estimate)
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

    /// Used by the "generate with AI" toggle: replaces the nutrition fields
    /// outright, since the estimate already covers the full current
    /// ingredient list. Adding onto whatever was there before would
    /// double-count every time the toggle is switched off and back on for
    /// the same ingredients.
    private func setNutritionEstimate(_ estimate: NutritionEstimate) {
        calories = String(estimate.calories)
        proteinGrams = formattedDecimal(estimate.protein)
        carbsGrams = formattedDecimal(estimate.carbs)
        fatGrams = formattedDecimal(estimate.fat)
    }

    /// Used by the photo-scan flow: each scan represents additional food
    /// items on top of whatever nutrition is already entered, so it
    /// deliberately accumulates rather than replacing.
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
<<<<<<< HEAD
        nutrition.logMeal(recipe: recipe, servings: 1, loggedAt: loggedAt)
=======
        nutrition.logMeal(recipe: recipe, servings: 1, loggedAt: selectedDate)
>>>>>>> main
    }
}
