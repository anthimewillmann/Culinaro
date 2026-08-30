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

struct CulinaroFieldBackground: View {
    enum Position {
        case single
        case first
        case middle
        case last

        static func forIndex(_ index: Int, count: Int) -> Position {
            if count <= 1 { return .single }
            if index == 0 { return .first }
            if index == count - 1 { return .last }
            return .middle
        }
    }

    let position: Position

    init(position: Position = .single) {
        self.position = position
    }

    var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: topRadius,
            bottomLeadingRadius: bottomRadius,
            bottomTrailingRadius: bottomRadius,
            topTrailingRadius: topRadius,
            style: .continuous
        )

        shape.fill(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private var topRadius: CGFloat {
        switch position {
        case .single, .first:
            12
        case .middle, .last:
            0
        }
    }

    private var bottomRadius: CGFloat {
        switch position {
        case .single, .last:
            12
        case .first, .middle:
            0
        }
    }
}

private struct MeadowBackgroundModifier: ViewModifier {
    @Environment(BackgroundModeManager.self) private var backgroundMode

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                if backgroundMode.meadowAnimationsEnabled {
                    MeadowView(animationStartDate: backgroundMode.meadowAnimationStartDate)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

extension View {
    /// Applies a subtle, randomised floating animation to the view.
    /// - Parameters:
    ///   - x: Maximum horizontal displacement in points. Default: `6`.
    ///   - y: Maximum vertical displacement in points. Default: `6`.
    ///   - duration: Half-period of one oscillation in seconds. Default: `1.2`.
    func wiggle(x: CGFloat = 6, y: CGFloat = 6, duration: Double = 1.2) -> some View {
        modifier(WiggleModifier(xAmount: x, yAmount: y, duration: duration))
    }

    func culinaroMeadowBackground() -> some View {
        modifier(MeadowBackgroundModifier())
    }
}
