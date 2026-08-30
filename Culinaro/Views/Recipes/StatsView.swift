import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var recipes: RecipeStore
    @EnvironmentObject private var lessons: LessonStore
    @EnvironmentObject private var stats: StatsStore
    @Environment(BackgroundModeManager.self) private var backgroundMode
    @State private var gameCenter = GameCenterManager.shared
    @State private var friendScores: [FriendScore] = []
    @State private var friendsErrorMessage: String?
    @State private var notes: [TextRow] = [TextRow(text: "")]
    @FocusState private var focusedNote: UUID?

    var body: some View {
        Form {
            streakSection

            Section("statistics") {
                let statistics = [
                    (String(localized: "created_recipes"), recipes.totalCreatedRecipes),
                    (String(localized: "created_lessons"), lessons.totalCreatedLessons),
                    (String(localized: "completed_cook_modes"), stats.completedCookModes),
                    (String(localized: "completed_lessons"), stats.completedLessons)
                ]

                ForEach(Array(statistics.enumerated()), id: \.offset) { index, item in
                    stat(item.0, item.1)
                        .listRowBackground(CulinaroFieldBackground(position: .forIndex(index, count: statistics.count)))
                }
            }

            friendsSection
            notesSection
            animationSettingsSection
        }
        .scrollContentBackground(.hidden)
        // Die animierte Wiese sitzt direkt hinter dem Formular, innerhalb
        // derselben View-Hierarchie — nicht mehr als externes Fenster
        // hinter der ganzen App. `.allowsHitTesting(false)` verhindert,
        // dass die Wiese selbst jemals Touches abbekommt.
        .culinaroMeadowBackground()
        .containerBackground(.clear, for: .navigation)
        .navigationTitle("overview")
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
        Section("streak") {
            stat(String(localized: "days"), stats.currentStreak)
                .listRowBackground(CulinaroFieldBackground())
        }
    }

    private var friendsSection: some View {
        Section("friends") {
            if !gameCenter.isAuthenticated {
                Button("sign_in") {
                    gameCenter.authenticate()
                }
                .listRowBackground(CulinaroFieldBackground())
            } else if let friendsErrorMessage {
                LabeledContent("error", value: friendsErrorMessage)
                    .listRowBackground(CulinaroFieldBackground())
            } else if friendScores.isEmpty {
                Text("no_entries")
                    .foregroundStyle(.secondary)
                    .listRowBackground(CulinaroFieldBackground())
            } else {
                ForEach(Array(friendScores.enumerated()), id: \.element.id) { index, score in
                    LabeledContent {
                        Text(score.score, format: .number)
                            .fontWeight(.semibold)
                    } label: {
                        Text(score.displayName)
                    }
                    .listRowBackground(CulinaroFieldBackground(position: .forIndex(index, count: friendScores.count)))
                }
            }
        }
    }

    private var notesSection: some View {
        Section("notes") {
            ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                TextField(String.localizedStringWithFormat(String(localized: "indexed_note_placeholder"), index + 1), text: noteBinding(index), axis: .vertical)
                    .focused($focusedNote, equals: note.id)
                    .onChange(of: notes[index].text) { _, value in
                        updateNotes(index: index, value: value, id: note.id)
                    }
                    .listRowBackground(CulinaroFieldBackground(position: .forIndex(index, count: notes.count)))
            }
        }
    }

    private var animationSettingsSection: some View {
        @Bindable var backgroundMode = backgroundMode

        return Section("animation_settings") {
            Toggle("meadow_animation", isOn: $backgroundMode.meadowAnimationsEnabled)
                .listRowBackground(CulinaroFieldBackground(position: .first))
            Toggle("cook_mode_animation", isOn: $backgroundMode.cookModeAnimationsEnabled)
                .listRowBackground(CulinaroFieldBackground(position: .last))
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
