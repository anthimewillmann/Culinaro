import SwiftUI
import FoundationModels

@Generable
struct CookingTip {
    @Guide(description: "Ein kurzer, hilfreicher Tipp (max. 15 Wörter)")
    var tip: String
}

struct CookModeView: View {
    let recipe: Recipe

    enum Phase: Equatable {
        case start
        case step(Int)
    }

    @State private var phase: Phase = .start
    @State private var currentTip: String? = nil
    @State private var isGeneratingTip = false
    @State private var tipsCache: [Int: String] = [:]
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var totalSteps: Int {
        recipe.steps.count + 1
    }

    var body: some View {
        ZStack {
            switch phase {
            case .start:
                List {
                    Section {
                        ForEach(recipe.ingredients, id: \.self) { ingredient in
                            Text(ingredient)
                        }
                    }
                }

            case .step(let index):
                ZStack {
                    // Hintergrund-Animation
                    WaveAnimationView()
                        .ignoresSafeArea()

                    // Blur-Overlay für bessere Lesbarkeit
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.5))
                        .ignoresSafeArea()

                    // Inhalt
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if index < recipe.steps.count {
                                Text(recipe.steps[index])
                                    .font(.largeTitle)
                                    .fontWeight(.semibold)
                                    .fixedSize(horizontal: false, vertical: true)

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
                                }

                            } else {
                                Text(NSLocalizedString("cook_mode_enjoy", comment: ""))
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                            }
                            Spacer(minLength: 40)
                        }
                        .padding()
                    }
                    .onChange(of: index) { _, newIndex in
                        if newIndex < recipe.steps.count {
                            Task { await loadTip(for: newIndex) }
                        } else {
                            currentTip = nil
                        }
                    }
                    .onAppear {
                        if index < recipe.steps.count {
                            Task { await loadTip(for: index) }
                        }
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
        .animation(.easeInOut, value: phase)
    }

    private func loadTip(for index: Int) async {
        if let cachedTip = tipsCache[index] {
            withAnimation { self.currentTip = cachedTip }
            return
        }

        currentTip = nil
        isGeneratingTip = true
        
        let session = LanguageModelSession()
        let stepText = recipe.steps[index]
        let prompt = "Gib mir einen sehr kurzen, praktischen Kochtipp für diesen Schritt: \(stepText)"

        do {
            let response = try await session.respond(to: prompt, generating: CookingTip.self)
            let generatedTip = response.content.tip
            
            await MainActor.run {
                self.tipsCache[index] = generatedTip
                withAnimation {
                    self.currentTip = generatedTip
                    self.isGeneratingTip = false
                }
            }
        } catch {
            await MainActor.run { self.isGeneratingTip = false }
        }
    }

    private func goBack() {
        switch phase {
        case .start: dismiss()
        case .step(let index): phase = index > 0 ? .step(index - 1) : .start
        }
    }

    private func goForward() {
        switch phase {
        case .start: phase = .step(0)
        case .step(let index):
            if index < totalSteps - 1 { phase = .step(index + 1) } else { dismiss() }
        }
    }

    private var trailingIcon: String {
        if case .step(let index) = phase, index == totalSteps - 1 { return "checkmark" }
        return "chevron.right"
    }

    private var title: String {
        switch phase {
        case .start: return NSLocalizedString("ingredients", comment: "")
        case .step(let index): return String.localizedStringWithFormat(NSLocalizedString("step_number", comment: ""), index + 1)
        }
    }

    private var subtitle: String {
        switch phase {
        case .start: return String.localizedStringWithFormat(NSLocalizedString("ingredients_count", comment: ""), recipe.ingredients.count)
        case .step: return String.localizedStringWithFormat(NSLocalizedString("of_steps", comment: ""), totalSteps)
        }
    }
}
