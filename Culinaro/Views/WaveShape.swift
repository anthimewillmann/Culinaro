import SwiftUI

// MARK: - WaveShape

/// An animatable wave / liquid shape whose curvature, width, and height
/// are all driven by animated state variables in `WaveAnimationView`.
///
/// - `t`: Controls the lateral oscillation of the wave's bezier control points (0…1).
/// - `expand`: Expands the shape horizontally to fill the full screen width (0…1).
/// - `waveRise`: Lifts the top edge of the shape upward (0 = bottom, 1 = resting position).
struct WaveShape: Shape {
    var t: CGFloat
    var expand: CGFloat
    var waveRise: CGFloat

    private let baseYScale: CGFloat        = 0.63
    private let expandYScaleBonus: CGFloat = 0.54
    private let pathHeight: CGFloat        = 180
    private let pathWidth: CGFloat         = 100

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(t, expand), waveRise) }
        set { t = newValue.first.first; expand = newValue.first.second; waveRise = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        /// Linear interpolation helper; uses `t` when `v < 0`.
        func lerp(_ a: CGFloat, _ b: CGFloat, _ v: CGFloat = -1) -> CGFloat {
            let factor = v < 0 ? t : v
            return a + (b - a) * factor
        }

        let leftX        = 20 * (1 - expand)
        let rightX       = 80 + 20 * expand
        let scaleYFactor = baseYScale + expandYScaleBonus * expand
        let riseOffset   = (1 - waveRise) * rect.height * 0.55

        var path = Path()
        path.move(to: CGPoint(x: leftX, y: 0 + riseOffset / (rect.height / pathHeight)))
        path.addCurve(
            to:       CGPoint(x: leftX, y: pathHeight),
            control1: CGPoint(x: lerp(50, -10) * (1 - expand) - 10 * expand, y: 60),
            control2: CGPoint(x: lerp(-10, 50) * (1 - expand) - 10 * expand, y: 120)
        )
        path.addLine(to: CGPoint(x: rightX, y: pathHeight))
        path.addCurve(
            to:       CGPoint(x: rightX, y: 0 + riseOffset / (rect.height / pathHeight)),
            control1: CGPoint(x: lerp(50, 110) * (1 - expand) + 110 * expand, y: 120),
            control2: CGPoint(x: lerp(110, 50) * (1 - expand) + 110 * expand, y: 60)
        )
        path.closeSubpath()

        let scaleX    = rect.width / pathWidth
        let scaleY    = rect.height * scaleYFactor / pathHeight
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
            .translatedBy(x: 0, y: riseOffset / scaleY)
        return path.applying(transform)
    }
}
