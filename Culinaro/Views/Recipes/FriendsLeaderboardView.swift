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
                    Label("game_center_not_signed_in", systemImage: "person.crop.circle.badge.exclamationmark")
                } description: {
                    Text("game_center_sign_in_description")
                } actions: {
                    Button("sign_in") {
                        gameCenter.authenticate()
                    }
                }
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("leaderboard_unavailable", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("reload") {
                        Task { await loadScores() }
                    }
                }
            } else if scores.isEmpty && !isLoading {
                ContentUnavailableView(
                    "no_entries",
                    systemImage: "person.2.slash",
                    description: Text("friends_leaderboard_empty_description")
                )
            } else {
                Form {
                    Section("friends") {
                        ForEach(scores) { score in
                            scoreRow(score)
                        }
                    }
                }
            }
        }
        .navigationTitle("friends")
        .task {
            await loadScores()
        }
        .refreshable {
            await loadScores()
        }
        .onChange(of: gameCenter.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                Task { await loadScores() }
            }
        }
    }

    private func scoreRow(_ score: FriendScore) -> some View {
        LabeledContent {
            Text(score.score, format: .number)
                .foregroundStyle(.secondary)
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
