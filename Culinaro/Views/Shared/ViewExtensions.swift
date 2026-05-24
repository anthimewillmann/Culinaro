import SwiftUI

// MARK: - WiggleModifier

/// Applies a continuous, randomised positional offset to any view,
/// creating a gentle floating / wiggling effect.
struct WiggleModifier: ViewModifier {
    let xAmount: CGFloat
    let yAmount: CGFloat
    let duration: Double
    @State private var offset: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .offset(offset)
            .onAppear {
                let randomPhase = Double.random(in: 0...duration)
                DispatchQueue.main.asyncAfter(deadline: .now() + randomPhase) {
                    withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                        offset = CGSize(
                            width:  CGFloat.random(in: -xAmount...xAmount),
                            height: CGFloat.random(in: -yAmount...yAmount)
                        )
                    }
                }
            }
    }
}

// MARK: - View Extension

extension View {
    /// Applies a subtle, randomised floating animation to the view.
    /// - Parameters:
    ///   - x: Maximum horizontal displacement in points. Default: `6`.
    ///   - y: Maximum vertical displacement in points. Default: `6`.
    ///   - duration: Half-period of one oscillation in seconds. Default: `1.2`.
    func wiggle(x: CGFloat = 6, y: CGFloat = 6, duration: Double = 1.2) -> some View {
        modifier(WiggleModifier(xAmount: x, yAmount: y, duration: duration))
    }
}
