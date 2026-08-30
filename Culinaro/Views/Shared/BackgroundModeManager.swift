import Foundation
import Observation

/// Controls which animated backgrounds are visible across the app.
@Observable
final class BackgroundModeManager {
    enum BackgroundMode: Equatable {
        case meadow
        case cookMode
    }

    var mode: BackgroundMode = .meadow
    var meadowAnimationsEnabled = true {
        didSet {
            if meadowAnimationsEnabled && !oldValue {
                meadowAnimationStartDate = Date()
            }
        }
    }
    var cookModeAnimationsEnabled = true {
        didSet {
            if cookModeAnimationsEnabled && !oldValue {
                cookModeAnimationRestartID = UUID()
            }
        }
    }
    var meadowAnimationStartDate = Date()
    var cookModeAnimationRestartID = UUID()
}
