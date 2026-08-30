import SwiftUI
import PhotosUI

struct ShoppingListView: View {
    @EnvironmentObject private var store: ShoppingListStore
    @Environment(RecipeAIService.self) private var aiService
    @State private var categoriesByID: [UUID: String] = [:]
    @State private var categoryOrder: [String] = []
    @State private var isCategorizing = false
    @State private var isShowingHistory = false

    private let pendingCategoryID = "__pendingCategory__"

    private var items: [ShoppingListItem] {
        store.items.sorted { $0.createdAt > $1.createdAt }
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
                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                        row(for: item)
                            .listRowBackground(CulinaroFieldBackground(position: .forIndex(index, count: group.items.count)))
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
                    .listRowBackground(CulinaroFieldBackground())
                }
            }

            Section("history") {
                Button {
                    isShowingHistory = true
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("shopping_history")
                        Text(historyCountText(store.recentHistory.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
<<<<<<< HEAD
                .buttonStyle(.plain)
                .listRowBackground(CulinaroFieldBackground())
=======
                .meadowRowBackground()
>>>>>>> main
            }

            Section {
                NavigationLink {
                    ShoppingHistoryView()
                } label: {
                    Label("history", systemImage: "clock.arrow.circlepath")
                }
            }
            .meadowRowBackground()
        }
        .scrollContentBackground(.hidden)
        // Die animierte Wiese sitzt direkt hinter der Liste, innerhalb
        // derselben View-Hierarchie — nicht mehr als externes Fenster
        // hinter der ganzen App. Dadurch muss keine private UIKit-
        // Navigations-Container-View mehr von außen transparent gemacht
        // werden, was zuvor das Scrollen im Leerraum zwischen Zeilen
        // dauerhaft gestört hat. `.ignoresSafeArea()` sorgt dafür, dass die
        // Wiese trotzdem die komplette Bildschirmfläche als Bezugsgröße
        // bekommt (sonst rechnet ihr GeometryReader nur mit dem Bereich
        // zwischen Navigationsleiste und Tab-Bar, wodurch alle intern als
        // Bruchteile davon positionierten Elemente verschoben/abgeschnitten
        // wirken). `.allowsHitTesting(false)` verhindert, dass die Wiese
        // selbst jemals Touches abbekommt.
        .culinaroMeadowBackground()
        .containerBackground(.clear, for: .navigation)
<<<<<<< HEAD
        .overlay { if items.isEmpty && store.recentHistory.isEmpty { ContentUnavailableView("no_items", systemImage: "cart") } }
=======
        .syncErrorBanner(store.syncError)
        .overlay { if items.isEmpty { ContentUnavailableView("no_items", systemImage: "cart") } }
>>>>>>> main
        .navigationTitle("shopping")
        .navigationSubtitle(subtitle)
        .navigationDestination(isPresented: $isShowingHistory) {
            ShoppingHistoryView()
        }
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

    private func historyCountText(_ count: Int) -> String {
        if count == 1 {
            String(localized: "one_history_entry")
        } else {
            String.localizedStringWithFormat(String(localized: "history_entries_count"), count)
        }
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
<<<<<<< HEAD
        HStack(alignment: .top, spacing: 12) {
            Button {
                store.toggleChecked(item)
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
=======
        Button {
            store.toggleChecked(item)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? .blue : .secondary)
>>>>>>> main
                    .contentTransition(.symbolEffect(.replace))

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

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .meadowRowBackground()
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

private struct ShoppingHistoryView: View {
    @EnvironmentObject private var store: ShoppingListStore

    private var groups: [(minutesAgo: Int, entries: [ShoppingListHistoryEntry])] {
        let now = Date()
        let grouped = Dictionary(grouping: store.recentHistory) { entry in
            max(0, min(59, Int(now.timeIntervalSince(entry.checkedAt) / 60)))
        }
        return grouped.keys.sorted().map { minutesAgo in
            (minutesAgo, grouped[minutesAgo, default: []].sorted { $0.checkedAt > $1.checkedAt })
        }
    }

    var body: some View {
        List {
            ForEach(groups, id: \.minutesAgo) { group in
                Section {
                    ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                        historyRow(for: entry)
                            .listRowBackground(CulinaroFieldBackground(position: .forIndex(index, count: group.entries.count)))
                    }
                } header: {
                    Text(minutesHeader(for: group.minutesAgo))
                }
            }
        }
        .overlay {
            if groups.isEmpty {
                ContentUnavailableView("no_recent_history", systemImage: "clock.arrow.circlepath")
            }
        }
        .scrollContentBackground(.hidden)
        .culinaroMeadowBackground()
        .containerBackground(.clear, for: .navigation)
        .navigationTitle("shopping_history")
    }

    private func minutesHeader(for minutesAgo: Int) -> String {
        if minutesAgo == 1 {
            String(localized: "one_minute_ago")
        } else {
            String.localizedStringWithFormat(String(localized: "minutes_ago"), minutesAgo)
        }
    }

    private func historyRow(for entry: ShoppingListHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.name)
                Spacer()
                if let quantity = entry.quantity, !quantity.isEmpty {
                    Text(quantity)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let sourceRecipeTitle = entry.sourceRecipeTitle {
                Text(String.localizedStringWithFormat(String(localized: "from_source"), sourceRecipeTitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

        // Die aktuell bearbeitete Zeile bleibt erhalten, auch wenn sie im Moment
        // leer ist (sonst verschwindet sie mitten in der Eingabe und der Fokus
        // geht verloren), ebenso die ursprünglich letzte Zeile (der Platzhalter
        // bleibt bestehen, auch wenn gerade eine andere Zeile leer ist). Ein
        // neuer Platzhalter wird nur angehängt, wenn danach keine leere Zeile
        // mehr am Ende steht — verhindert doppelte leere Zeilen, falls die
        // bearbeitete Zeile selbst zur letzten wird.
        let lastIndex = array.indices.last
        var compacted = array.enumerated()
            .filter { index, row in !isEmpty(row) || row.id == id || index == lastIndex }
            .map(\.element)
        if compacted.last.map(isEmpty) != true {
            compacted.append(TextRow(text: ""))
        }

        rows.wrappedValue = compacted
        focusedField = id
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
                _ = appendGeneratedIngredients(parsed.items)
                isProcessing = false
                generationTask = nil
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
