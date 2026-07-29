import Observation

/// Controls which permanently mounted animated background is visible.
@Observable
final class BackgroundModeManager {
    enum BackgroundMode: Equatable {
        case meadow
        case cookMode
    }

    var mode: BackgroundMode = .meadow
}
