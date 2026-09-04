import Foundation
import Observation

/// Coordinates the app-wide animated backgrounds and their restart state.
@Observable
final class BackgroundModeManager {
    enum BackgroundMode: Equatable {
        case meadow
        case cookMode
    }

    private enum DefaultsKey {
        static let meadowAnimationEnabled = "culinaro.stats.meadowAnimationEnabled"
        static let cookModeAnimationEnabled = "culinaro.stats.cookModeAnimationEnabled"
    }

    var mode: BackgroundMode = .meadow

    var isMeadowAnimationEnabled: Bool {
        didSet {
            defaults.set(isMeadowAnimationEnabled, forKey: DefaultsKey.meadowAnimationEnabled)

            if isMeadowAnimationEnabled {
                meadowAnimationStartDate = .now
            }
        }
    }

    var isCookModeAnimationEnabled: Bool {
        didSet {
            defaults.set(isCookModeAnimationEnabled, forKey: DefaultsKey.cookModeAnimationEnabled)

            if isCookModeAnimationEnabled {
                cookModeAnimationRestartID = UUID()
            }
        }
    }

    private(set) var meadowAnimationStartDate = Date.now
    private(set) var cookModeAnimationRestartID = UUID()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isMeadowAnimationEnabled = defaults.object(forKey: DefaultsKey.meadowAnimationEnabled) as? Bool ?? true
        isCookModeAnimationEnabled = defaults.object(forKey: DefaultsKey.cookModeAnimationEnabled) as? Bool ?? true
    }
}
