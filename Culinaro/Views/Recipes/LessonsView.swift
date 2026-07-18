import SwiftUI

/// Zeigt alle Lektionen, gruppiert in Sections, deren Überschriften vom
/// Modell selbst festgelegt werden (z. B. Backen/Kochen/Grundtechniken) —
/// passend zum aktuell vorhandenen Titel-Set.
struct LessonsView: View {
    @EnvironmentObject private var store: LessonStore
    @EnvironmentObject private var shoppingListStore: ShoppingListStore
    @Environment(RecipeAIService.self) private var aiService
    @State private var editingLesson: Lesson?
    @State private var categoriesByID: [UUID: String] = [:]
    @State private var categoryOrder: [String] = []
    @Binding var isSelecting: Bool
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

    private var lessonExportForToolbar: PDFExport {
        selectedLessonExport ?? PDFExport(data: Data(), filename: "Lektionen.pdf")
    }

    private var groupedLessons: [(category: String, lessons: [Lesson])] {
        let groups = Dictionary(grouping: lessons) { categoriesByID[$0.id] ?? "Weitere" }
        let orderedKeys = categoryOrder + groups.keys.filter { !categoryOrder.contains($0) }.sorted()
        return orderedKeys.compactMap { key in
            guard let items = groups[key], !items.isEmpty else { return nil }
            return (key, items)
        }
    }

    private var categorizationSignature: String {
        lessons.map { "\($0.id.uuidString):\($0.title)" }.joined(separator: "|")
    }

    var body: some View {
        List {
            ForEach(groupedLessons, id: \.category) { group in
                Section(group.category) {
                    ForEach(group.lessons) { lesson in
                        row(for: lesson)
                    }
                }
            }
        }
        .overlay { if lessons.isEmpty { ContentUnavailableView("Noch keine Lektionen", systemImage: "graduationcap") } }
        .navigationTitle("Lektionen")
        .navigationSubtitle("\(store.lessons.count) erstellt")
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
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: lesson.id) {
                rowContent(for: lesson)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { store.delete(lesson) } label: { Label("Löschen", systemImage: "trash") }
                Button { editingLesson = lesson } label: { Label("Bearbeiten", systemImage: "pencil") }.tint(.blue)
            }
            .swipeActions(edge: .leading) {
                Button { withAnimation { store.togglePin(lesson) } } label: {
                    Label(lesson.isPinned ? "Lösen" : "Anpinnen", systemImage: lesson.isPinned ? "pin.slash" : "pin")
                }.tint(.orange)
            }
            .contextMenu {
                Button { editingLesson = lesson } label: { Label("Bearbeiten", systemImage: "pencil") }
                Button { store.togglePin(lesson) } label: { Label(lesson.isPinned ? "Lösen" : "Anpinnen", systemImage: "pin") }
                Button { shoppingListStore.addIngredients(from: lesson) } label: { Label("Zutaten zum Einkauf", systemImage: "cart.badge.plus") }
                if let pdf = PDFExporter.export(lesson) {
                    ShareLink(item: pdf, preview: SharePreview(lesson.title, image: Image(systemName: "doc.richtext"))) {
                        Label("Exportieren", systemImage: "square.and.arrow.up")
                    }
                }
                Button(role: .destructive) { store.delete(lesson) } label: { Label("Löschen", systemImage: "trash") }
            }
        }
    }

    private func rowContent(for lesson: Lesson) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title).fontWeight(.semibold)
                Text("\(lesson.steps.count) Schritte").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if lesson.isPinned { Image(systemName: "pin.fill").foregroundStyle(.orange) }
        }
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
                .accessibilityLabel("Zum Einkauf hinzufügen")

                ShareLink(item: lessonExportForToolbar, preview: SharePreview("Lektionen", image: Image(systemName: "doc.richtext"))) {
                    Label("Exportieren", systemImage: "square.and.arrow.up")
                }
                .disabled(selectedLessonExport == nil)
                .accessibilityLabel("Ausgewählte Lektionen exportieren")

                Button(role: .destructive) {
                    deleteSelectedLessons()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(selectedLessonIDs.isEmpty)
                .accessibilityLabel("Ausgewählte Lektionen löschen")

                Spacer()
            }
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
            return
        }

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
            }
        } catch {
            // Bleibt einfach unkategorisiert unter "Weitere".
        }
    }
}
