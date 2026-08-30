import SwiftUI
import Combine

/// Zeigt alle in der letzten Stunde abgehakten Einkaufslisten-Einträge,
/// gruppiert nach der exakten Anzahl Minuten seit dem Abhaken (die zuletzt
/// abgehakten Einträge zuerst). Liest aus `store.checkedHistory` statt aus
/// `store.items` — bleibt dadurch auch dann korrekt, wenn ein Eintrag
/// inzwischen über "Erledigte löschen" oder einzeln entfernt wurde.
struct ShoppingHistoryView: View {
    @EnvironmentObject private var store: ShoppingListStore
    // Treibt die Minuten-Buckets und das 1-Stunden-Fenster weiter, solange
    // die Ansicht offen bleibt — sonst bewegt sich hier nichts mehr, sobald
    // `store.checkedHistory` (die einzige @Published-Quelle) sich nicht
    // ändert, selbst wenn in Wirklichkeit Minuten oder Stunden vergehen.
    @State private var now = Date()
    private let refreshTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    private var historyItems: [ShoppingHistoryEntry] {
        store.checkedHistory.filter { now.timeIntervalSince($0.checkedAt) <= 3600 }
    }

    private var groupedItems: [(minutesAgo: Int, items: [ShoppingHistoryEntry])] {
        let groups = Dictionary(grouping: historyItems) { entry in
            Int(now.timeIntervalSince(entry.checkedAt) / 60)
        }
        return groups.keys.sorted().map { minutes in
            (minutes, groups[minutes]!.sorted { $0.checkedAt > $1.checkedAt })
        }
    }

    var body: some View {
        List {
            ForEach(groupedItems, id: \.minutesAgo) { group in
                Section(minutesAgoLabel(for: group.minutesAgo)) {
                    ForEach(group.items) { entry in
                        row(for: entry)
                    }
                }
                .meadowRowBackground()
            }
        }
        .scrollContentBackground(.hidden)
        .background(MeadowView().ignoresSafeArea().allowsHitTesting(false))
        .containerBackground(.clear, for: .navigation)
        .overlay { if historyItems.isEmpty { ContentUnavailableView("no_history", systemImage: "clock.arrow.circlepath") } }
        .navigationTitle("history")
        .onReceive(refreshTimer) { now = $0 }
    }

    private func row(for entry: ShoppingHistoryEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.itemName)
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

    private func minutesAgoLabel(for minutes: Int) -> String {
        String.localizedStringWithFormat(String(localized: "minutes_ago"), max(1, minutes))
    }
}
