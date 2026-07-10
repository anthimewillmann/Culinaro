import GameKit
import SwiftUI

struct FriendsLeaderboardView: View {
    @State private var gameCenter = GameCenterManager.shared
    @State private var scores: [FriendScore] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if !gameCenter.isAuthenticated {
                ContentUnavailableView {
                    Label("Game Center nicht angemeldet", systemImage: "person.crop.circle.badge.exclamationmark")
                } description: {
                    Text("Melde dich an, um deine Gesamtpunktzahl mit Freunden zu vergleichen.")
                } actions: {
                    Button("Anmelden") {
                        gameCenter.authenticate()
                    }
                }
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Rangliste nicht verfügbar", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Erneut laden") {
                        Task { await loadScores() }
                    }
                }
            } else if scores.isEmpty && !isLoading {
                ContentUnavailableView(
                    "Keine Einträge",
                    systemImage: "person.2.slash",
                    description: Text("Sobald du oder deine Freunde Punkte eingereicht haben, erscheinen sie hier.")
                )
            } else {
                Form {
                    Section("Freunde") {
                        ForEach(scores) { score in
                            scoreRow(score)
                        }
                    }
                }
            }
        }
        .navigationTitle("Freunde")
        .task {
            await loadScores()
        }
        .refreshable {
            await loadScores()
        }
    }

    private func scoreRow(_ score: FriendScore) -> some View {
        LabeledContent {
            Text(score.score, format: .number)
                .fontWeight(isLocalPlayer(score) ? .bold : .semibold)
                .foregroundStyle(isLocalPlayer(score) ? Color.accentColor : Color.primary)
        } label: {
            Text(score.displayName)
                .fontWeight(isLocalPlayer(score) ? .bold : .regular)
                .foregroundStyle(isLocalPlayer(score) ? Color.accentColor : Color.primary)
        }
    }

    private func loadScores() async {
        guard gameCenter.isAuthenticated else { return }

        isLoading = true
        errorMessage = nil

        do {
            scores = try await gameCenter.loadFriendsLeaderboard()
        } catch {
            scores = []
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func isLocalPlayer(_ score: FriendScore) -> Bool {
        score.id == GKLocalPlayer.local.gamePlayerID
    }
}
