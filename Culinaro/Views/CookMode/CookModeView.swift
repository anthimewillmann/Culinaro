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
    let recipe: Recipe

    /// Represents the current navigation phase within the cook mode.
    enum Phase: Equatable {
        case start
        case step(Int)
    }

    @State private var phase: Phase = .start
    @State private var currentTip: String? = nil
    @State private var isGeneratingTip = false

    /// In-session cache mapping step index → generated tip string.
    @State private var tipsCache: [Int: String] = [:]

    /// Tracks the current tip-loading task so it can be cancelled on navigation.
    @State private var tipTask: Task<Void, Never>? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(RecipeAIService.self) private var aiService

    /// Total number of phases: ingredients screen + all steps.
    private var totalSteps: Int { recipe.steps.count + 1 }

    var body: some View {
        ZStack {
            switch phase {

            // MARK: – Ingredients list
            case .start:
                List {
                    Section {
                        ForEach(recipe.ingredients, id: \.self) { ingredient in
                            Text(ingredient)
                        }
                    }
                }

            // MARK: – Individual step
            case .step(let index):
                ZStack {
                    // Animated background
                    CookModeAnimationView()
                        .ignoresSafeArea()

                    // Readability overlay adapts to light / dark mode
                    Rectangle()
                        .fill(colorScheme == .dark
                              ? Color.black.opacity(0.5)
                              : Color.white.opacity(0.5))
                        .ignoresSafeArea()

                    // Step content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if index < recipe.steps.count {
                                Text(recipe.steps[index])
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
                                // Final "enjoy" screen
                                Text(NSLocalizedString("cook_mode_enjoy", comment: ""))
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
            // Cancel any in-flight tip request before starting a new one
            tipTask?.cancel()
            tipTask = nil
            currentTip = nil
            isGeneratingTip = false

            if case .step(let index) = newPhase, index < recipe.steps.count {
                tipTask = Task { await loadTip(for: index) }
            }
        }
        .onAppear {
            // Load tip if the view appears directly on a step (edge case)
            if case .step(let index) = phase, index < recipe.steps.count {
                tipTask = Task { await loadTip(for: index) }
            }
        }
    }

    // MARK: - Tip Loading

    /// Loads the AI-generated tip for the given step index.
    /// Returns immediately if tips are disabled or a cached tip exists.
    /// Checks for task cancellation before writing back to state.
    private func loadTip(for index: Int) async {
        guard recipe.tipsEnabled else { return }

        if let cached = tipsCache[index] {
            guard !Task.isCancelled else { return }
            withAnimation { currentTip = cached }
            return
        }

        isGeneratingTip = true

        do {
            let tip = try await aiService.cookingTip(for: recipe.steps[index])
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
            if index < totalSteps - 1 { phase = .step(index + 1) } else { dismiss() }
        }
    }

    /// Icon for the trailing toolbar button based on the current phase.
    private var trailingIcon: String {
        if case .step(let index) = phase, index == totalSteps - 1 { return "checkmark" }
        return "chevron.right"
    }

    /// Navigation bar title for the current phase.
    private var title: String {
        switch phase {
        case .start: return NSLocalizedString("ingredients", comment: "")
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
                NSLocalizedString("ingredients_count", comment: ""), recipe.ingredients.count
            )
        case .step:
            return String.localizedStringWithFormat(
                NSLocalizedString("of_steps", comment: ""), totalSteps
            )
        }
    }
}
