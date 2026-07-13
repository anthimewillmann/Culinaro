import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject private var store: ShoppingListStore
    @Environment(RecipeAIService.self) private var aiService
    @State private var categoriesByID: [UUID: String] = [:]
    @State private var categoryOrder: [String] = []
    @State private var showAddItem = false

    private var items: [ShoppingListItem] {
        store.items.sorted { $0.createdAt > $1.createdAt }
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
        .navigationTitle("Einkaufsliste")
        .navigationSubtitle(subtitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddItem = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Artikel hinzufügen")
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddShoppingListItemSheet()
        }
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
                    Text("aus: \(sourceRecipeTitle)")
                        .font(.caption)
                        .foregroundStyle(.tint)
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

private struct AddShoppingListItemSheet: View {
    @EnvironmentObject private var store: ShoppingListStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var quantity = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case quantity
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Artikel") {
                    TextField("Name", text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.done)
                        .onSubmit(addAndReset)
                    TextField("Menge", text: $quantity)
                        .focused($focusedField, equals: .quantity)
                        .submitLabel(.done)
                        .onSubmit(addAndReset)
                }
            }
            .navigationTitle("Hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onAppear { focusedField = .name }
        }
    }

    private func addAndReset() {
        store.add(name: name, quantity: quantity)
        name = ""
        quantity = ""
        focusedField = .name
    }
}
