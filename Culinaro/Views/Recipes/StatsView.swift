import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var recipes: RecipeStore
    @EnvironmentObject private var lessons: LessonStore
    @EnvironmentObject private var stats: StatsStore
    @State private var gameCenter = GameCenterManager.shared
    @State private var friendScores: [FriendScore] = []
    @State private var friendsErrorMessage: String?
    @State private var notes: [TextRow] = [TextRow(text: "")]
    @FocusState private var focusedNote: UUID?

    var body: some View {
        Form {
            streakSection

            Section("Statistik") {
                stat("Erstellte Rezepte", recipes.totalCreatedRecipes)
                stat("Erstellte Lektionen", lessons.totalCreatedLessons)
                stat("Abgeschlossene Kochmodi", stats.completedCookModes)
                stat("Abgeschlossene Lektionen", stats.completedLessons)
            }

            friendsSection
            notesSection
        }
        .navigationTitle("Übersicht")
        .onAppear(perform: loadNotes)
        .task {
            await loadFriendScores()
        }
        .refreshable {
            await loadFriendScores()
        }
        .onChange(of: gameCenter.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                Task { await loadFriendScores() }
            } else {
                friendScores = []
                friendsErrorMessage = nil
            }
        }
    }

    private var streakSection: some View {
        Section("Streak") {
            stat("Tage", stats.currentStreak)
        }
    }

    private var friendsSection: some View {
        Section("Freunde") {
            if !gameCenter.isAuthenticated {
                Button("Anmelden") {
                    gameCenter.authenticate()
                }
            } else if let friendsErrorMessage {
                LabeledContent("Fehler", value: friendsErrorMessage)
            } else if friendScores.isEmpty {
                Text("Keine Einträge")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(friendScores) { score in
                    LabeledContent {
                        Text(score.score, format: .number)
                            .fontWeight(.semibold)
                    } label: {
                        Text(score.displayName)
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Anmerkungen") {
            ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                TextField("\(index + 1). Anmerkung", text: noteBinding(index), axis: .vertical)
                    .focused($focusedNote, equals: note.id)
                    .onChange(of: notes[index].text) { _, value in
                        updateNotes(index: index, value: value, id: note.id)
                    }
            }
        }
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        LabeledContent {
            Text(value, format: .number)
                .fontWeight(.semibold)
        } label: {
            Text(title)
        }
    }

    private func noteBinding(_ index: Int) -> Binding<String> {
        Binding(get: { notes[index].text }, set: { notes[index].text = $0 })
    }

    private func updateNotes(index: Int, value: String, id: UUID) {
        let isEmpty: (TextRow) -> Bool = { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        if index == notes.count - 1 && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notes.append(TextRow(text: ""))
        }

        let trailingPlaceholder = notes.last.flatMap { isEmpty($0) ? $0 : nil }
        var compacted = notes.filter { !isEmpty($0) }
        compacted.append(trailingPlaceholder ?? TextRow(text: ""))

        notes = compacted
        focusedNote = compacted.contains { $0.id == id } ? id : nil
        saveNotes()
    }

    private func loadFriendScores() async {
        guard gameCenter.isAuthenticated else { return }

        friendsErrorMessage = nil

        do {
            friendScores = try await gameCenter.loadFriendsLeaderboard()
        } catch {
            friendScores = []
            friendsErrorMessage = error.localizedDescription
        }
    }

    private func loadNotes() {
        let loadedNotes = stats.allergies
            .split(whereSeparator: { $0.isNewline || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        notes = loadedNotes.map { TextRow(text: $0) } + [TextRow(text: "")]
    }

    private func saveNotes() {
        stats.allergies = notes
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
