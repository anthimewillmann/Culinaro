import Foundation
import Combine

@MainActor
final class StatsStore: ObservableObject {
    @Published var completedCookModes: Int { didSet { save() } }
    @Published var completedLessons: Int { didSet { save() } }
    @Published var allergies: String { didSet { save() } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        completedCookModes = defaults.integer(forKey: "culinaro.stats.cookModes")
        completedLessons = defaults.integer(forKey: "culinaro.stats.lessons")
        allergies = defaults.string(forKey: "culinaro.stats.allergies") ?? ""
    }

    func recordCompletion(_ kind: CompletionKind) {
        switch kind {
        case .recipe: completedCookModes += 1
        case .lesson: completedLessons += 1
        }
    }

    private func save() {
        defaults.set(completedCookModes, forKey: "culinaro.stats.cookModes")
        defaults.set(completedLessons, forKey: "culinaro.stats.lessons")
        defaults.set(allergies, forKey: "culinaro.stats.allergies")
    }
}
