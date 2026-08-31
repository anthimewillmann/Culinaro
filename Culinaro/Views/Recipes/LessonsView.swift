import SwiftUI

/// Zeigt alle Lektionen, gruppiert in Sections, deren Überschriften vom
/// Modell selbst festgelegt werden (z. B. Backen/Kochen/Grundtechniken) —
/// passend zum aktuell vorhandenen Titel-Set.
struct LessonsView: View {
    @EnvironmentObject private var store: LessonStore
    @EnvironmentObject private var shoppingListStore: ShoppingListStore
    @EnvironmentObject private var nutritionStore: NutritionStore
    @Environment(RecipeAIService.self) private var aiService
    @State private var editingLesson: Lesson?
    @State private var categoriesByID: [UUID: String] = [:]
    @State private var categoryOrder: [String] = []
    @State private var isCategorizing = false
    @Binding var isSelecting: Bool
    @Binding var navigationPath: [UUID]

    private let pinnedCategoryID = "__pinnedCategory__"
    private let pendingCategoryID = "__pendingCategory__"
    @State private var selectedLessonIDs: Set<UUID> = []

    private var lessons: [Lesson] {
        store.lessons.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.createdAt > $1.createdAt
        }
    }

    private var selectedLessons: [Lesson] {
        lessons.filter { selectedLessonIDs.contains($0.id) }
    }

    private var selectedLessonExport: PDFExport? {
        PDFExporter.export(selectedLessons.map { $0 as any Cookable }, filename: "Lektionen")
    }

    private var hasSelectedLessonsWithNutritionInput: Bool {
        selectedLessons.contains { $0.nutrition != nil || !$0.ingredients.isEmpty }
    }

    private var lessonExportForToolbar: PDFExport {
        selectedLessonExport ?? PDFExport(data: Data(), filename: "Lektionen.pdf")
    }

    private var groupedLessons: [(category: String, lessons: [Lesson])] {
        let pinnedLessons = lessons.filter(\.isPinned)
        let regularLessons = lessons.filter { !$0.isPinned }
        let groups = Dictionary(grouping: regularLessons) { categoriesByID[$0.id] ?? pendingCategoryID }
        let orderedKeys = categoryOrder
            + groups.keys.filter { !categoryOrder.contains($0) && $0 != pendingCategoryID }.sorted()
            + (groups[pendingCategoryID]?.isEmpty == false ? [pendingCategoryID] : [])

        var result: [(category: String, lessons: [Lesson])] = []
        if !pinnedLessons.isEmpty {
            result.append((pinnedCategoryID, pinnedLessons))
        }
        result += orderedKeys.compactMap { key in
            guard let items = groups[key], !items.isEmpty else { return nil }
            return (key, items)
        }
        return result
    }

    private var categorizationSignature: String {
        store.lessons
            .map { "\($0.id.uuidString):\($0.title)" }
            .sorted()
            .joined(separator: "|")
    }

    var body: some View {
        List {
            ForEach(groupedLessons, id: \.category) { group in
                Section {
                    ForEach(group.lessons) { lesson in
                        row(for: lesson)
                    }
                } header: {
                    categoryHeader(for: group.category)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ManagedAnimationBackgroundView())
        .containerBackground(.clear, for: .navigation)
        .overlay { if lessons.isEmpty { ContentUnavailableView("no_lessons", systemImage: "graduationcap") } }
        .navigationTitle("lessons")
        .navigationSubtitle(String.localizedStringWithFormat(String(localized: "created_count"), store.lessons.count))
        .refreshable { await store.syncFromCloud() }
        .sheet(item: $editingLesson) { AddItemView(editingLesson: $0) }
        .toolbar { selectionToolbar }
        .onChange(of: isSelecting) { _, isSelecting in
            if !isSelecting { selectedLessonIDs.removeAll() }
        }
        .onChange(of: lessons) { _, lessons in
            let availableIDs = Set(lessons.map(\.id))
            selectedLessonIDs = selectedLessonIDs.intersection(availableIDs)
            if lessons.isEmpty { isSelecting = false }
        }
        .task(id: categorizationSignature) {
            await categorize()
        }
    }

    @ViewBuilder
    private func row(for lesson: Lesson) -> some View {
        if isSelecting {
            Button {
                toggleSelection(for: lesson)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: selectedLessonIDs.contains(lesson.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedLessonIDs.contains(lesson.id) ? .blue : .secondary)
                        .imageScale(.large)
                    rowContent(for: lesson)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                navigationPath.append(lesson.id)
            } label: {
                rowContent(for: lesson)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { store.delete(lesson) } label: { Label("delete", systemImage: "trash") }
                Button { editingLesson = lesson } label: { Label("edit", systemImage: "pencil") }.tint(.blue)
                if let pdf = PDFExporter.export(lesson) {
                    ShareLink(item: pdf, preview: SharePreview(lesson.title, image: Image(systemName: "doc.richtext"))) {
                        Label("export", systemImage: "square.and.arrow.up")
                    }
                    .tint(Color(red: 0.48, green: 0.44, blue: 1.0))
                }
            }
            .swipeActions(edge: .leading) {
                Button { withAnimation { store.togglePin(lesson) } } label: {
                    Label(LocalizedStringKey(lesson.isPinned ? "unpin" : "pin"), systemImage: lesson.isPinned ? "pin.slash" : "pin")
                }.tint(.orange)
            }
            .contextMenu {
                Button { editingLesson = lesson } label: { Label("edit", systemImage: "pencil") }
                Button { store.togglePin(lesson) } label: { Label(LocalizedStringKey(lesson.isPinned ? "unpin" : "pin"), systemImage: "pin") }
                Button { shoppingListStore.addIngredients(from: lesson) } label: { Label("add_ingredients_to_shopping", systemImage: "cart.badge.plus") }
                Button { Task { await addNutrition(for: lesson) } } label: { Label("add_to_nutrition", systemImage: "heart.text.square") }
                    .disabled(lesson.nutrition == nil && lesson.ingredients.isEmpty)
                if let pdf = PDFExporter.export(lesson) {
                    ShareLink(item: pdf, preview: SharePreview(lesson.title, image: Image(systemName: "doc.richtext"))) {
                        Label("export", systemImage: "square.and.arrow.up")
                    }
                }
                Button(role: .destructive) { store.delete(lesson) } label: { Label("delete", systemImage: "trash") }
            }
        }
    }

    private func rowContent(for lesson: Lesson) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title).fontWeight(.semibold)
                Text(String.localizedStringWithFormat(String(localized: "steps_count"), lesson.steps.count + 1)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    @ToolbarContentBuilder
    private var selectionToolbar: some ToolbarContent {
        if isSelecting {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    addSelectedIngredientsToShoppingList()
                } label: {
                    Image(systemName: "cart.badge.plus")
                }
                .disabled(selectedLessonIDs.isEmpty)
                .accessibilityLabel("add_to_shopping")

                Button {
                    addSelectedNutrition()
                } label: {
                    Image(systemName: "heart.text.square")
                }
                .disabled(!hasSelectedLessonsWithNutritionInput)
                .accessibilityLabel("add_to_nutrition")

                ShareLink(item: lessonExportForToolbar, preview: SharePreview(String(localized: "lessons"), image: Image(systemName: "doc.richtext"))) {
                    Label("export", systemImage: "square.and.arrow.up")
                }
                .disabled(selectedLessonExport == nil)
                .accessibilityLabel("export_selected_lessons")

                Spacer()

                Button {
                    deleteSelectedLessons()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(selectedLessonIDs.isEmpty)
                .accessibilityLabel("delete_selected_lessons")
            }
        }
    }

    @ViewBuilder
    private func categoryHeader(for category: String) -> some View {
        if category == pinnedCategoryID {
            Text("pinned")
        } else if category == pendingCategoryID {
            ProgressView()
                .controlSize(.small)
        } else {
            Text(category)
        }
    }

    private func toggleSelection(for lesson: Lesson) {
        if selectedLessonIDs.contains(lesson.id) {
            selectedLessonIDs.remove(lesson.id)
        } else {
            selectedLessonIDs.insert(lesson.id)
        }
    }

    private func addSelectedIngredientsToShoppingList() {
        for lesson in selectedLessons {
            shoppingListStore.addIngredients(from: lesson)
        }
        finishSelection()
    }

    private func addSelectedNutrition() {
        let lessonsToLog = selectedLessons.filter { !$0.ingredients.isEmpty }
        finishSelection()
        Task {
            for lesson in lessonsToLog {
                await addNutrition(for: lesson)
            }
        }
    }

    private func addNutrition(for lesson: Lesson) async {
        if let nutrition = lesson.nutrition {
            let recipe = Recipe(
                title: lesson.title,
                ingredients: lesson.ingredients,
                steps: lesson.steps,
                nutrition: nutrition
            )
            nutritionStore.logMeal(recipe: recipe, servings: 1)
            return
        }

        guard !lesson.ingredients.isEmpty else { return }

        do {
            let estimate = try await aiService.estimateNutrition(title: lesson.title, ingredients: lesson.ingredients)
            let recipe = Recipe(
                title: lesson.title,
                ingredients: lesson.ingredients,
                steps: lesson.steps,
                nutrition: NutritionInfo(
                    calories: estimate.calories,
                    proteinGrams: estimate.protein,
                    carbsGrams: estimate.carbs,
                    fatGrams: estimate.fat,
                    servings: max(estimate.servings, 1)
                )
            )
            await MainActor.run {
                nutritionStore.logMeal(recipe: recipe, servings: 1)
            }
        } catch {
            // Nutrition logging is optional; unavailable estimates should not block the lesson UI.
        }
    }

    private func deleteSelectedLessons() {
        for lesson in selectedLessons {
            store.delete(lesson)
        }
        finishSelection()
    }

    private func finishSelection() {
        withAnimation {
            selectedLessonIDs.removeAll()
            isSelecting = false
        }
    }

    private func categorize() async {
        guard !lessons.isEmpty else {
            categoriesByID = [:]
            categoryOrder = []
            isCategorizing = false
            return
        }

        isCategorizing = true
        categoriesByID = [:]
        categoryOrder = []

        let items = lessons.map { RecipeAIService.CategorizableItem(id: $0.id.uuidString, title: $0.title) }
        do {
            let assignments = try await aiService.categorize(items, contextHint: "Diese Einträge sind Koch-Lektionen, die eine Technik Schritt für Schritt lehren")
            var byID: [UUID: String] = [:]
            var order: [String] = []
            for lesson in lessons {
                if let category = assignments[lesson.id.uuidString] {
                    byID[lesson.id] = category
                    if !order.contains(category) { order.append(category) }
                }
            }
            withAnimation {
                categoriesByID = byID
                categoryOrder = order
                isCategorizing = false
            }
        } catch {
            // Bleibt im Ladezustand, damit kein unkategorisierter Text-Fallback erscheint.
        }
    }
}
