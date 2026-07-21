import SwiftUI
import PhotosUI

struct ShoppingListView: View {
    let searchText: String

    @EnvironmentObject private var store: ShoppingListStore
    @Environment(RecipeAIService.self) private var aiService
    @State private var categoriesByID: [UUID: String] = [:]
    @State private var categoryOrder: [String] = []
    @State private var isCategorizing = false

    private let pendingCategoryID = "__pendingCategory__"

    init(searchText: String = "") {
        self.searchText = searchText
    }

    private var items: [ShoppingListItem] {
        store.items
            .filter { item in
                searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText) || item.sourceRecipeTitle?.localizedCaseInsensitiveContains(searchText) == true
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var groupedItems: [(category: String, items: [ShoppingListItem])] {
        let groups = Dictionary(grouping: items) { categoriesByID[$0.id] ?? $0.category ?? pendingCategoryID }
        let orderedKeys = categoryOrder
            + groups.keys.filter { !categoryOrder.contains($0) && $0 != pendingCategoryID }.sorted()
            + (groups[pendingCategoryID]?.isEmpty == false ? [pendingCategoryID] : [])
        return orderedKeys.compactMap { key in
            guard let items = groups[key], !items.isEmpty else { return nil }
            return (key, items)
        }
    }

    private var categorizationSignature: String {
        items
            .map { "\($0.id.uuidString):\($0.name)" }
            .sorted()
            .joined(separator: "|")
    }

    var body: some View {
        List {
            ForEach(groupedItems, id: \.category) { group in
                Section {
                    ForEach(group.items) { item in
                        row(for: item)
                    }
                } header: {
                    categoryHeader(for: group.category)
                }
            }

            if store.items.contains(where: \.isChecked) {
                Section {
                    Button(role: .destructive) {
                        store.deleteAllChecked()
                    } label: {
                        Text("delete_completed")
                    }
                }
            }
        }
        .overlay { if items.isEmpty { ContentUnavailableView("no_items", systemImage: "cart") } }
        .navigationTitle("shopping")
        .navigationSubtitle(subtitle)
        .refreshable { await store.syncFromCloud() }
        .task(id: categorizationSignature) {
            await categorize()
        }
    }

    private var subtitle: String {
        let countText = String.localizedStringWithFormat(String(localized: "items_count"), store.items.count)
        guard store.plannedCalories > 0 else { return countText }
        return String.localizedStringWithFormat(String(localized: "planned_calories_subtitle"), countText, store.plannedCalories)
    }

    @ViewBuilder
    private func categoryHeader(for category: String) -> some View {
        if category == pendingCategoryID {
            ProgressView()
                .controlSize(.small)
        } else {
            Text(category)
        }
    }

    private func row(for item: ShoppingListItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                store.delete(item)
            } label: {
                Image(systemName: "circle")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.name)
                        .strikethrough(item.isChecked)
                        .foregroundStyle(item.isChecked ? .secondary : .primary)
                    Spacer()
                    if let quantity = item.quantity, !quantity.isEmpty {
                        Text(quantity)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let sourceRecipeTitle = item.sourceRecipeTitle {
                    Text(String.localizedStringWithFormat(String(localized: "from_source"), sourceRecipeTitle))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { store.delete(item) } label: { Label("delete", systemImage: "trash") }
        }
    }

    private func categorize() async {
        guard !items.isEmpty else {
            categoriesByID = [:]
            categoryOrder = []
            isCategorizing = false
            return
        }

        isCategorizing = true

        let itemsToCategorize = items.map { RecipeAIService.CategorizableItem(id: $0.id.uuidString, title: $0.name) }
        do {
            let assignments = try await aiService.categorize(itemsToCategorize, contextHint: "Das sind Einkaufslisten-Einträge, gruppiere nach Supermarkt-Abteilung")
            var byID: [UUID: String] = [:]
            var order: [String] = []
            for item in items {
                if let category = assignments[item.id.uuidString] {
                    byID[item.id] = category
                    if !order.contains(category) { order.append(category) }
                }
            }
            withAnimation {
                categoriesByID = byID
                categoryOrder = order
                isCategorizing = false
            }
            store.applyCategories(byID)
        } catch {
            // Bleibt im Ladezustand, damit kein unkategorisierter Text-Fallback erscheint.
        }
    }
}

struct AddShoppingListItemSheet: View {
    @EnvironmentObject private var store: ShoppingListStore
    @Environment(RecipeAIService.self) private var aiService
    @Environment(\.dismiss) private var dismiss

    @State private var ingredients = [TextRow(text: "")]
    @State private var isProcessing = false
    @State private var generationTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var selectedPhoto: PhotosPickerItem?
    @FocusState private var focusedField: UUID?

    private var hasIngredients: Bool {
        !cleanedIngredients.isEmpty && !isProcessing
    }

    private var cleanedIngredients: [String] {
        ingredients
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                dynamicSection(title: "ingredients", placeholderTitle: String(localized: "ingredient"), rows: $ingredients)

                Section("scan") {
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
            }
            .navigationTitle("add_ingredient")
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
                    if hasIngredients {
                        Button {
                            save()
                            dismiss()
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

                    if isProcessing && index == 0 {
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

        let trailingPlaceholder = array.last.flatMap { isEmpty($0) ? $0 : nil }
        var compacted = array.filter { !isEmpty($0) }
        compacted.append(trailingPlaceholder ?? TextRow(text: ""))

        rows.wrappedValue = compacted
        focusedField = compacted.contains { $0.id == id } ? id : nil
    }

    private func cancelGenerationIfNeeded() {
        guard generationTask != nil, isProcessing else { return }
        generationTask?.cancel()
        generationTask = nil
        isProcessing = false
    }

    private func process(_ image: UIImage) {
        generationTask?.cancel()
        isProcessing = true
        errorMessage = nil
        generationTask = Task {
            do {
                let parsed = try await aiService.scanShoppingList(image: image)
                try Task.checkCancellation()
                if appendGeneratedIngredients(parsed.items) {
                    isProcessing = false
                    generationTask = nil
                }
            } catch is CancellationError {
                isProcessing = false
                generationTask = nil
            } catch {
                // Match recipe/lesson generation: keep the inline loading indicator visible when generation fails.
                errorMessage = nil
            }
        }
    }

    private func appendGeneratedIngredients(_ generatedIngredients: [String]) -> Bool {
        let existingValues = cleanedIngredients
        let newValues = generatedIngredients
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !newValues.isEmpty else { return false }
        ingredients = (existingValues + newValues).map { TextRow(text: $0) } + [TextRow(text: "")]
        focusedField = ingredients.last?.id
        return true
    }

    private func save() {
        for ingredient in cleanedIngredients {
            store.add(name: ingredient)
        }
    }
}
