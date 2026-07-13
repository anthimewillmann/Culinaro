import SwiftUI

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
                .foregroundStyle(.primary)
        }
    }

    private func formattedWholeNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    private func formattedDecimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
