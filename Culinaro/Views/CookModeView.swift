import SwiftUI

struct CookModeView: View {
    let recipe: Recipe

    enum Phase: Equatable {
        case start
        case step(Int)
    }

    @State private var phase: Phase = .start
    @Environment(\.dismiss) private var dismiss

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
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        if index < recipe.steps.count {
                            Text(recipe.steps[index])
                                .font(.largeTitle)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("cook_mode_enjoy")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(title)
        .navigationSubtitle(subtitle)
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {

            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    goBack()
                } label: {
                    if phase == .start {
                        Image(systemName: "xmark")
                    } else {
                        Label("back", systemImage: "chevron.left")
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    goForward()
                } label: {
                    Image(systemName: trailingIcon)
                        .font(.body)
                        .fontWeight(.semibold)
                }
            }
        }
        .animation(.easeInOut, value: phase)
    }

    // MARK: - Navigation Logic

    private func goBack() {
        switch phase {
        case .start:
            dismiss()

        case .step(let index):
            if index > 0 {
                phase = .step(index - 1)
            } else {
                phase = .start
            }
        }
    }

    private func goForward() {
        switch phase {
        case .start:
            phase = .step(0)

        case .step(let index):
            if index < totalSteps - 1 {
                phase = .step(index + 1)
            } else {
                dismiss()
            }
        }
    }

    private var trailingIcon: String {
        if case .step(let index) = phase, index == totalSteps - 1 {
            return "checkmark"
        }
        return "chevron.right"
    }

    // MARK: - Localized Title & Subtitle

    private var title: String {
        switch phase {
        case .start:
            return NSLocalizedString("ingredients", comment: "")
        case .step(let index):
            return String.localizedStringWithFormat(
                NSLocalizedString("step_number", comment: ""),
                index + 1
            )
        }
    }

    private var subtitle: String {
        switch phase {
        case .start:
            return String.localizedStringWithFormat(
                NSLocalizedString("ingredients_count", comment: ""),
                recipe.ingredients.count
            )
        case .step:
            return String.localizedStringWithFormat(
                NSLocalizedString("of_steps", comment: ""),
                totalSteps
            )
        }
    }
}
