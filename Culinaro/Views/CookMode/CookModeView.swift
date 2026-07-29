import SwiftUI

/// Step-by-step cooking view for a given recipe.
///
/// Navigation phases:
/// - `.start` – Shows the ingredient list.
/// - `.step(n)` – Shows step `n` with an optional AI-generated tip.
///
/// Tips are loaded asynchronously and cached per session to avoid redundant API calls.
/// `CookModeAnimationView` runs as an animated background during cooking steps.
struct CookModeView: View {
    let item: any Cookable

    /// Represents the current navigation phase within the cook mode.
    enum Phase: Equatable {
        case start
        case step(Int)
    }

    @State private var phase: Phase = .start
    @State private var currentTip: String? = nil
    @State private var isGeneratingTip = false
    @State private var servingsEaten = 1.0
    @State private var didLogMeal = false
    @State private var estimatedNutrition: NutritionInfo?
    @State private var isEstimatingNutrition = false
    @State private var didAttemptNutritionEstimate = false

    /// In-session cache mapping step index → generated tip string.
    @State private var tipsCache: [Int: String] = [:]

    /// Tracks the current tip-loading task so it can be cancelled on navigation.
    @State private var tipTask: Task<Void, Never>? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(RecipeAIService.self) private var aiService
    @EnvironmentObject private var statsStore: StatsStore
    @EnvironmentObject private var nutritionStore: NutritionStore
    @EnvironmentObject private var shoppingListStore: ShoppingListStore
    @EnvironmentObject private var recipeStore: RecipeStore
    @Environment(BackgroundModeManager.self) private var backgroundMode

    /// Total number of phases: ingredients screen + all steps.
    private var totalSteps: Int { item.steps.count + 1 }

    var body: some View {
        ZStack {
            switch phase {

            // MARK: – Ingredients list
            case .start:
                List {
                    if !item.ingredients.isEmpty {
                        Section("ingredients") {
                            ForEach(item.ingredients, id: \.self) { ingredient in Text(ingredient) }
                        }

                        nutritionSummarySection

                        Section("shopping") {
                            Button {
                                addIngredientsToShoppingList()
                            } label: {
                                Text("add_ingredients_to_shopping")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listRowBackground(Color.clear)

            // MARK: – Individual step
            case .step(let index):
                ZStack {
                    // Readability overlay adapts to light / dark mode
                    Rectangle()
                        .fill(colorScheme == .dark
                              ? Color.black.opacity(0.5)
                              : Color.white.opacity(0.5))
                        .ignoresSafeArea()

                    // Step content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if index < item.steps.count {
                                Text(item.steps[index])
                                    .font(.largeTitle)
                                    .fontWeight(.semibold)
                                    .fixedSize(horizontal: false, vertical: true)

                                // Tip and loading indicator animate independently
                                // of the phase transition to prevent flying/disappearing.
                                Group {
                                    if let tip = currentTip {
                                        Text(tip)
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 8)
                                            .transition(.opacity)
                                    } else if isGeneratingTip {
                                        ProgressView()
                                            .controlSize(.small)
                                            .padding(.top, 8)
                                            .transition(.opacity)
                                    }
                                }
                                .animation(.easeInOut(duration: 0.3), value: currentTip)
                                .animation(.easeInOut(duration: 0.3), value: isGeneratingTip)

                            } else {
                                Text(finalStepText)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                            }
                            Spacer(minLength: 40)
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationSubtitle(subtitle)
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .containerBackground(.clear, for: .navigation)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: goBack) {
                    if phase == .start {
                        Image(systemName: "xmark")
                    } else {
                        Label("back", systemImage: "chevron.left")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: goForward) {
                    Image(systemName: trailingIcon)
                        .font(.body)
                        .fontWeight(.semibold)
                }
            }
        }
        // MARK: – Tip loading on phase change
        .onChange(of: phase) { _, newPhase in
            updateBackgroundMode(for: newPhase)

            // Cancel any in-flight tip request before starting a new one
            tipTask?.cancel()
            tipTask = nil
            currentTip = nil
            isGeneratingTip = false

            if case .step(let index) = newPhase, index < item.steps.count {
                tipTask = Task { await loadTip(for: index) }
            }
        }
        .onAppear {
            estimateMissingNutritionIfNeeded()

            // Load tip if the view appears directly on a step (edge case)
            if case .step(let index) = phase, index < item.steps.count {
                tipTask = Task { await loadTip(for: index) }
            }
        }
        .task {
            updateBackgroundMode(for: phase)
        }
        .onDisappear {
            backgroundMode.mode = .meadow
        }
    }

    // MARK: - Nutrition Logging

    private var nutritionSummarySection: some View {
        Section("food_section") {
            nutritionField(String(localized: "calories"), nutritionValue?.calories.map { "\($0)" })
            nutritionField(String(localized: "protein"), nutritionValue?.proteinGrams.map(gramsText))
            nutritionField(String(localized: "carbs"), nutritionValue?.carbsGrams.map(gramsText))
            nutritionField(String(localized: "fat"), nutritionValue?.fatGrams.map(gramsText))

            if let recipe = item as? Recipe, let nutrition = nutritionValue {
                Stepper(value: $servingsEaten, in: 0.5...10, step: 0.5) {
                    Text(String.localizedStringWithFormat(String(localized: "servings_count"), servingsEaten.formatted(.number.precision(.fractionLength(0...1)))))
                }

                Button {
                    logMeal(recipe.withNutrition(nutrition))
                } label: {
                    Label(LocalizedStringKey(didLogMeal ? "logged" : "log_as_eaten"), systemImage: didLogMeal ? "checkmark.circle.fill" : "fork.knife")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var nutritionValue: NutritionInfo? {
        let storedNutrition: NutritionInfo?
        if let recipe = item as? Recipe {
            storedNutrition = recipe.nutrition
        } else if let lesson = item as? Lesson {
            storedNutrition = lesson.nutrition
        } else {
            storedNutrition = nil
        }

        guard let storedNutrition else { return estimatedNutrition }
        guard let estimatedNutrition else { return storedNutrition }
        return NutritionInfo(
            calories: storedNutrition.calories ?? estimatedNutrition.calories,
            proteinGrams: storedNutrition.proteinGrams ?? estimatedNutrition.proteinGrams,
            carbsGrams: storedNutrition.carbsGrams ?? estimatedNutrition.carbsGrams,
            fatGrams: storedNutrition.fatGrams ?? estimatedNutrition.fatGrams,
            servings: storedNutrition.servings
        )
    }

    private func nutritionField(_ title: String, _ value: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let value {
                Text(value)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private func gramsText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)))) g"
    }

    private func logMeal(_ recipe: Recipe) {
        nutritionStore.logMeal(recipe: recipe, servings: servingsEaten)
        withAnimation { didLogMeal = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                withAnimation { didLogMeal = false }
            }
        }
    }

    private func estimateMissingNutritionIfNeeded() {
        guard !didAttemptNutritionEstimate,
              !item.ingredients.isEmpty else { return }

        let storedNutrition: NutritionInfo?
        if let recipe = item as? Recipe {
            storedNutrition = recipe.nutrition
        } else if let lesson = item as? Lesson {
            storedNutrition = lesson.nutrition
        } else {
            storedNutrition = nil
        }

        if let storedNutrition,
           storedNutrition.calories != nil,
           storedNutrition.proteinGrams != nil,
           storedNutrition.carbsGrams != nil,
           storedNutrition.fatGrams != nil {
            return
        }

        didAttemptNutritionEstimate = true
        isEstimatingNutrition = true

        Task {
            do {
                let estimate = try await aiService.estimateNutrition(title: item.title, ingredients: item.ingredients)
                let nutrition = NutritionInfo(
                    calories: estimate.calories,
                    proteinGrams: estimate.protein,
                    carbsGrams: estimate.carbs,
                    fatGrams: estimate.fat,
                    servings: max(estimate.servings, 1)
                )
                await MainActor.run {
                    estimatedNutrition = nutrition
                    isEstimatingNutrition = false
                    if let recipe = item as? Recipe {
                        recipeStore.save(recipe.withNutrition(nutrition), editing: recipe)
                    }
                }
            } catch {
                await MainActor.run {
                    isEstimatingNutrition = false
                }
            }
        }
    }

    private func addIngredientsToShoppingList() {
        if let recipe = item as? Recipe {
            shoppingListStore.addIngredients(from: recipe)
        } else if let lesson = item as? Lesson {
            shoppingListStore.addIngredients(from: lesson)
        }
    }

    private func updateBackgroundMode(for phase: Phase) {
        switch phase {
        case .start:
            backgroundMode.mode = .meadow
        case .step:
            backgroundMode.mode = .cookMode
        }
    }

    // MARK: - Tip Loading

    /// Loads the AI-generated tip for the given step index.
    /// Returns immediately if tips are disabled or a cached tip exists.
    /// Checks for task cancellation before writing back to state.
    private func loadTip(for index: Int) async {
        guard item.tipsEnabled else { return }

        if let cached = tipsCache[index] {
            guard !Task.isCancelled else { return }
            withAnimation { currentTip = cached }
            return
        }

        isGeneratingTip = true

        do {
            let tip = try await aiService.cookingTip(for: item.steps[index])
            guard !Task.isCancelled else { return }
            await MainActor.run {
                tipsCache[index] = tip
                withAnimation {
                    currentTip = tip
                    isGeneratingTip = false
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            await MainActor.run { isGeneratingTip = false }
        }
    }

    // MARK: - Navigation

    /// Navigates backwards: step → previous step → ingredient list → dismiss.
    private func goBack() {
        switch phase {
        case .start: dismiss()
        case .step(let index): phase = index > 0 ? .step(index - 1) : .start
        }
    }

    /// Navigates forwards: ingredient list → first step → … → last step → dismiss.
    private func goForward() {
        switch phase {
        case .start: phase = .step(0)
        case .step(let index):
            if index < totalSteps - 1 {
                phase = .step(index + 1)
            } else {
                statsStore.recordCompletion(item.completionKind)
                dismiss()
            }
        }
    }

    /// Icon for the trailing toolbar button based on the current phase.
    private var trailingIcon: String {
        if case .step(let index) = phase, index == totalSteps - 1 { return "checkmark" }
        return "chevron.right"
    }

    private var finalStepText: String {
        item is Lesson ? String(localized: "practice") : NSLocalizedString("cook_mode_enjoy", comment: "")
    }

    /// Navigation bar title for the current phase.
    private var title: String {
        switch phase {
        case .start: return item.ingredients.isEmpty ? String(localized: "overview") : NSLocalizedString("ingredients", comment: "")
        case .step(let index):
            return String.localizedStringWithFormat(
                NSLocalizedString("step_number", comment: ""), index + 1
            )
        }
    }

    /// Navigation bar subtitle for the current phase.
    private var subtitle: String {
        switch phase {
        case .start:
            return String.localizedStringWithFormat(
                NSLocalizedString("ingredients_count", comment: ""), item.ingredients.count
            )
        case .step:
            return String.localizedStringWithFormat(
                NSLocalizedString("of_steps", comment: ""), totalSteps
            )
        }
    }
}
private extension Recipe {
    func withNutrition(_ nutrition: NutritionInfo) -> Recipe {
        Recipe(
            id: id,
            title: title,
            ingredients: ingredients,
            steps: steps,
            isPinned: isPinned,
            tipsEnabled: tipsEnabled,
            wasGenerated: wasGenerated,
            nutrition: nutrition,
            createdAt: createdAt
        )
    }
}
