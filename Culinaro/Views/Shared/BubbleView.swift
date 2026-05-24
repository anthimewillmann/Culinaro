import SwiftUI

// MARK: - Bubble

/// Data model representing a single floating bubble in the wave animation.
/// Position is expressed as fractions of the enclosing view's size (0…1).
struct Bubble: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var delay: Double
}

// MARK: - BubbleView

/// Animates a single expanding, fading circle at a fixed position.
/// Loops indefinitely: grows from 0 to `maxSize`, then fades out, then repeats.
struct BubbleView: View {
    let x: CGFloat
    let y: CGFloat
    let delay: Double
    let geo: GeometryProxy
    let hide: Bool

    @State private var size: CGFloat = 0
    @State private var opacity: CGFloat = 1.0
    @State private var isActive: Bool = true

    let strokeWidth: CGFloat = 5
    let maxSize: CGFloat = 160

    var body: some View {
        Circle()
            .strokeBorder(Color(red: 0.9, green: 0.9, blue: 0.9), lineWidth: strokeWidth)
            .frame(width: size, height: size)
            .opacity(hide ? 0 : opacity)
            .position(x: x * geo.size.width, y: y * geo.size.height)
            .onAppear { startCycle(after: delay) }
            .onDisappear { isActive = false }
    }

    // MARK: - Animation

    /// Starts one expand-and-fade cycle, then schedules the next recursively.
    /// Stops automatically when the view disappears (`isActive = false`).
    private func startCycle(after delay: Double) {
        guard isActive else { return }
        size = 0
        opacity = 1.0
        withAnimation(.easeOut(duration: 4.5).delay(delay)) { size = maxSize }
        withAnimation(.easeIn(duration: 1.2).delay(delay + 3.3)) { opacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 4.5) {
            guard isActive else { return }
            startCycle(after: 0)
        }
    }
}
