import SwiftUI
import Combine

/// Zeigt alle geloggten Mahlzeiten der letzten Tage, gruppiert nach Tag
/// ("Heute" bzw. "Vor x Tagen"). Jeder Tag hat am Ende eine Zeile, um für
/// genau diesen Tag eine weitere Mahlzeit nachzutragen.
struct HealthHistoryView: View {
    @EnvironmentObject private var nutrition: NutritionStore
    @State private var addMealDate: Date?
    // Ohne das würde ein Mitternachts-Wechsel während die Ansicht offen ist
    // die "Heute"/"Vor x Tagen"-Header nicht aktualisieren, da sich
    // `nutrition.loggedMeals` dabei nicht ändert.
    @State private var now = Date()
    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var groupedMeals: [(day: Date, meals: [LoggedMeal])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: nutrition.loggedMeals) { calendar.startOfDay(for: $0.loggedAt) }
        return groups.keys.sorted(by: >).map { day in
            (day, groups[day]!.sorted { $0.loggedAt > $1.loggedAt })
        }
    }

    var body: some View {
        List {
            ForEach(groupedMeals, id: \.day) { group in
                Section(dayLabel(for: group.day)) {
                    ForEach(group.meals) { meal in
                        NavigationLink {
                            MealDetailView(meal: meal)
                        } label: {
                            mealRow(meal)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            nutrition.deleteMeal(group.meals[index])
                        }
                    }

                    Button {
                        addMealDate = initialLogDate(for: group.day)
                    } label: {
                        Label("add_meal_for_day", systemImage: "plus.circle")
                    }
                }
                .meadowRowBackground()
            }
        }
        .scrollContentBackground(.hidden)
        .background(MeadowView().ignoresSafeArea().allowsHitTesting(false))
        .containerBackground(.clear, for: .navigation)
        .overlay { if nutrition.loggedMeals.isEmpty { ContentUnavailableView("no_history", systemImage: "clock.arrow.circlepath") } }
        .navigationTitle("history")
        .sheet(isPresented: Binding(
            get: { addMealDate != nil },
            set: { if !$0 { addMealDate = nil } }
        )) {
            if let addMealDate {
                AddHealthRecipeSheet(initialDate: addMealDate)
            }
        }
        .onReceive(refreshTimer) { now = $0 }
    }

    private func mealRow(_ meal: LoggedMeal) -> some View {
        HStack {
            Text(meal.recipeTitle)
            Spacer()
            Text("\(meal.calories) kcal")
                .foregroundStyle(.secondary)
        }
    }

    private func dayLabel(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(day, inSameDayAs: now) {
            return String(localized: "today")
        }
        let daysAgo = calendar.dateComponents([.day], from: day, to: calendar.startOfDay(for: now)).day ?? 0
        return String.localizedStringWithFormat(String(localized: "days_ago"), daysAgo)
    }

    /// Übernimmt die Tageszahl von `day`, aber die aktuelle Uhrzeit — sonst
    /// würde ein für einen vergangenen Tag nachgetragenes Essen immer exakt
    /// um Mitternacht gespeichert und dadurch beim Sortieren nach `loggedAt`
    /// (neueste zuerst) stets ans Ende dieses Tages rutschen.
    private func initialLogDate(for day: Date) -> Date {
        let calendar = Calendar.current
        let now = calendar.dateComponents([.hour, .minute, .second], from: Date())
        return calendar.date(
            bySettingHour: now.hour ?? 0,
            minute: now.minute ?? 0,
            second: now.second ?? 0,
            of: day
        ) ?? day
    }
}

/// Detailansicht einer einzelnen geloggten Mahlzeit mit Kalorien/Makros.
struct MealDetailView: View {
    let meal: LoggedMeal

    var body: some View {
        Form {
            Section {
                LabeledContent("meal", value: meal.recipeTitle)
                LabeledContent("servings", value: meal.servingsEaten.formatted(.number.precision(.fractionLength(0...1))))
                LabeledContent("date") {
                    Text(meal.loggedAt, format: .dateTime.day().month().year().hour().minute())
                }
            }

            Section("nutrition_facts") {
                LabeledContent(String(localized: "calories"), value: "\(meal.calories) kcal")
                LabeledContent(String(localized: "protein"), value: meal.proteinGrams.formatted(.number.precision(.fractionLength(0...1))))
                LabeledContent(String(localized: "carbs"), value: meal.carbsGrams.formatted(.number.precision(.fractionLength(0...1))))
                LabeledContent(String(localized: "fat"), value: meal.fatGrams.formatted(.number.precision(.fractionLength(0...1))))
            }
        }
        .navigationTitle(meal.recipeTitle)
    }
}
