import Foundation
import Observation

/// Coordinates the app-wide animated backgrounds and their restart state.
@Observable
final class BackgroundModeManager {
    enum BackgroundMode: Equatable {
        case meadow
        case cookMode
    }

    var mode: BackgroundMode = .meadow

    var isMeadowAnimationEnabled = true {
        didSet {
            if isMeadowAnimationEnabled {
                meadowAnimationStartDate = .now
            }
        }
    }

    var isCookModeAnimationEnabled = true {
        didSet {
            if isCookModeAnimationEnabled {
                cookModeAnimationRestartID = UUID()
            }
        }
    }

    private(set) var meadowAnimationStartDate = Date.now
    private(set) var cookModeAnimationRestartID = UUID()
}
