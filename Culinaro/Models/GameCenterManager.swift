import Foundation
import GameKit
import Observation
import UIKit

@MainActor
@Observable
final class GameCenterManager {
    static let shared = GameCenterManager()

    static let leaderboardID = "culinaro_total_score"

    private(set) var isAuthenticated = GKLocalPlayer.local.isAuthenticated

    private init() { }

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                if let viewController {
                    UIApplication.shared.topViewController()?.present(viewController, animated: true)
                }

                if let error {
                    print("Game Center authentication failed: \(error.localizedDescription)")
                }

                self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            }
        }
    }

    func submitTotalScore(_ value: Int) async {
        guard isAuthenticated else { return }

        do {
            try await GKLeaderboard.submitScore(
                value,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [Self.leaderboardID]
            )
        } catch {
            print("Game Center score submission failed: \(error.localizedDescription)")
        }
    }

    func loadFriendsLeaderboard() async throws -> [FriendScore] {
        let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [Self.leaderboardID])
        guard let leaderboard = leaderboards.first else { return [] }

        let result = try await leaderboard.loadEntries(
            for: .friendsOnly,
            timeScope: .allTime,
            range: NSRange(location: 1, length: 50)
        )

        var scores = result.1.map(FriendScore.init(entry:))
        let localPlayerID = GKLocalPlayer.local.gamePlayerID

        if !scores.contains(where: { $0.id == localPlayerID }) {
            if let localPlayerEntry = result.0 {
                scores.append(FriendScore(entry: localPlayerEntry))
            } else {
                scores.append(
                    FriendScore(
                        id: localPlayerID,
                        displayName: GKLocalPlayer.local.displayName,
                        score: 0
                    )
                )
            }
        }

        return scores.sorted { $0.score > $1.score }
    }
}

struct FriendScore: Identifiable, Equatable {
    let id: String
    let displayName: String
    let score: Int

    init(id: String, displayName: String, score: Int) {
        self.id = id
        self.displayName = displayName
        self.score = score
    }

    init(entry: GKLeaderboard.Entry) {
        id = entry.player.gamePlayerID
        displayName = entry.player.displayName
        score = entry.score
    }
}

private extension UIApplication {
    func topViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
    ) -> UIViewController? {
        if let navigationController = base as? UINavigationController {
            return topViewController(base: navigationController.visibleViewController)
        }

        if let tabBarController = base as? UITabBarController {
            return topViewController(base: tabBarController.selectedViewController)
        }

        if let presentedViewController = base?.presentedViewController {
            return topViewController(base: presentedViewController)
        }

        return base
    }
}
