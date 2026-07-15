import SwiftUI

struct ShoppingListView: View {
    let searchText: String

    @EnvironmentObject private var store: ShoppingListStore
    @Environment(RecipeAIService.self) private var aiService
    @State private var categoriesByID: [UUID: String] = [:]
    @State private var categoryOrder: [String] = []
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
        let groups = Dictionary(grouping: items) { categoriesByID[$0.id] ?? $0.category ?? "Weitere" }
        let orderedKeys = categoryOrder + groups.keys.filter { !categoryOrder.contains($0) }.sorted()
        return orderedKeys.compactMap { key in
            guard let items = groups[key], !items.isEmpty else { return nil }
            return (key, items)
        }
    }

    private var categorizationSignature: String {
        items.map { "\($0.id.uuidString):\($0.name)" }.joined(separator: "|")
    }

    var body: some View {
        List {
            ForEach(groupedItems, id: \.category) { group in
                Section(group.category) {
                    ForEach(group.items) { item in
                        row(for: item)
                    }
                }
            }

            if store.items.contains(where: \.isChecked) {
                Section {
                    Button(role: .destructive) {
                        store.deleteAllChecked()
                    } label: {
                        Text("Erledigte löschen")
                    }
                }
            }
        }
        .overlay { if items.isEmpty { ContentUnavailableView("Noch keine Artikel", systemImage: "cart") } }
        .navigationTitle("Einkauf")
        .navigationSubtitle(subtitle)
        .refreshable { await store.syncFromCloud() }
        .task(id: categorizationSignature) {
            await categorize()
        }
    }

    private var subtitle: String {
        let countText = "\(store.items.count) Artikel"
        guard store.plannedCalories > 0 else { return countText }
        return "\(countText) · ~\(store.plannedCalories) kcal geplant"
    }

    private func row(for item: ShoppingListItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                store.toggleChecked(item)
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
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
                    Text("aus \(sourceRecipeTitle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { store.delete(item) } label: { Label("Löschen", systemImage: "trash") }
        }
    }

    private func categorize() async {
        guard !items.isEmpty else {
            categoriesByID = [:]
            categoryOrder = []
            return
        }

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
            }
            store.applyCategories(byID)
        } catch {
            // Bleibt einfach unkategorisiert unter "Weitere".
        }
    }
}

struct AddShoppingListItemSheet: View {
    @EnvironmentObject private var store: ShoppingListStore
    @Environment(\.dismiss) private var dismiss
    @State private var ingredients = [TextRow(text: "")]
    @FocusState private var focusedField: UUID?

    private var hasIngredients: Bool {
        !cleanedIngredients.isEmpty
    }

    private var cleanedIngredients: [String] {
        ingredients
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                dynamicSection(title: "Zutaten", placeholderTitle: "Zutat", rows: $ingredients)
            }
            .navigationTitle("Zutat hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(!hasIngredients)
                }
            }
            .onAppear { focusedField = ingredients.first?.id }
        }
    }

    @ViewBuilder
    private func dynamicSection(title: String, placeholderTitle: String, rows: Binding<[TextRow]>) -> some View {
        Section(title) {
            ForEach(Array(rows.wrappedValue.enumerated()), id: \.element.id) { index, row in
                TextField("\(index + 1). \(placeholderTitle)", text: rowBinding(rows, index))
                    .focused($focusedField, equals: row.id)
                    .onChange(of: rows.wrappedValue[index].text) { _, value in
                        updateRows(rows, index: index, value: value, id: row.id)
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

    private func save() {
        for ingredient in cleanedIngredients {
            store.add(name: ingredient)
        }
    }
}
