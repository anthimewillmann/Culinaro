import SwiftUI

// MARK: - Shared Color

/// Shared colour used for all herb illustrations.
let herbColor = Color(red: 0.72, green: 0.91, blue: 0.60)

// MARK: - HerbZone

/// Defines a rectangular zone within the canvas where herbs are placed,
/// along with their count and size range.
struct HerbZone {
    var xRange: ClosedRange<CGFloat>
    var yRange: ClosedRange<CGFloat>
    var count: Int
    var sizeRange: ClosedRange<CGFloat>
}

// MARK: - PlacedHerb

/// A single placed herb instance with position, rotation, and size.
struct PlacedHerb: Identifiable {
    let id = UUID()
    let position: CGPoint
    let rotation: Double
    let size: CGFloat
}

// MARK: - Layout Helper

/// Distributes herbs evenly in a grid within the given zone, with small random offsets.
/// - Parameters:
///   - zone: The `HerbZone` defining placement bounds, count, and size range.
///   - canvasSize: The size of the containing canvas in points.
/// - Returns: An array of `PlacedHerb` values ready to render.
func placeHerbs(zone: HerbZone, in canvasSize: CGSize) -> [PlacedHerb] {
    let cols  = Int(ceil(sqrt(Double(zone.count))))
    let rows  = Int(ceil(Double(zone.count) / Double(cols)))
    let xStep = (zone.xRange.upperBound - zone.xRange.lowerBound) / CGFloat(max(cols - 1, 1))
    let yStep = (zone.yRange.upperBound - zone.yRange.lowerBound) / CGFloat(max(rows - 1, 1))
    var result = [PlacedHerb]()

    for row in 0..<rows {
        for col in 0..<cols {
            guard result.count < zone.count else { break }
            let x = canvasSize.width  * (zone.xRange.lowerBound + CGFloat(col) * xStep)
            let y = canvasSize.height * (zone.yRange.lowerBound + CGFloat(row) * yStep)
            result.append(PlacedHerb(
                position: CGPoint(x: x + CGFloat.random(in: -8...8),
                                  y: y + CGFloat.random(in: -8...8)),
                rotation: Double.random(in: -30...30),
                size:     CGFloat.random(in: zone.sizeRange)
            ))
        }
    }
    return result
}

// MARK: - Herb Views

/// A garlic illustration rendered as a small stroked circle.
struct GarlicView: View {
    var size: CGFloat = 48
    var body: some View {
        Circle()
            .stroke(herbColor, lineWidth: 6)
            .frame(width: size * 0.6, height: size * 0.6)
    }
}

/// A basil leaf illustration rendered as a filled double-curved oval.
struct BasilView: View {
    var size: CGFloat = 48
    var body: some View {
        let w = size * 0.6, h = size * 0.95
        let cx = size / 2, top = (size - h) / 2, bottom = (size + h) / 2
        return Path { p in
            p.move(to: CGPoint(x: cx, y: top))
            p.addQuadCurve(to: CGPoint(x: cx, y: bottom), control: CGPoint(x: cx + w, y: size / 2))
            p.addQuadCurve(to: CGPoint(x: cx, y: top),   control: CGPoint(x: cx - w, y: size / 2))
        }
        .fill(herbColor)
        .frame(width: size, height: size)
    }
}

/// A chive illustration rendered as a single vertical stroke.
struct ChivesView: View {
    var size: CGFloat = 48
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: size / 2, y: size * 1.1))
            p.addLine(to: CGPoint(x: size / 2, y: size * -0.4))
        }
        .stroke(herbColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
        .frame(width: size, height: size)
    }
}

/// A rosemary sprig illustration: a central stem with symmetrical lateral needles.
struct RosemaryView: View {
    var size: CGFloat = 48

    var body: some View {
        let positions: [CGFloat] = [0.10, 0.25, 0.42, 0.58, 0.74, 0.88]
        return ZStack {
            // Central stem
            Path { p in
                p.move(to: CGPoint(x: size / 2, y: size * 1.2))
                p.addLine(to: CGPoint(x: size / 2, y: size * -0.2))
            }
            .stroke(herbColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))

            // Lateral needles at each position along the stem
            ForEach(positions, id: \.self) { t in
                let y = size * t
                Path { p in
                    p.move(to: CGPoint(x: size / 2, y: y))
                    p.addLine(to: CGPoint(x: size / 2 - size * 0.25, y: y - size * 0.25))
                    p.move(to: CGPoint(x: size / 2, y: y))
                    p.addLine(to: CGPoint(x: size / 2 + size * 0.25, y: y - size * 0.25))
                }
                .stroke(herbColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - SoupLayoutPreview

/// The herb-scene overlay used in the final animation phase.
/// Distributes garlic, chives, rosemary, and basil across predefined zones
/// using `placeHerbs(_:in:)`.
struct SoupLayoutPreview: View {

    /// Zone definitions pairing a `HerbZone` with the herb type string.
    let zones: [(zone: HerbZone, type: String)] = [
        (HerbZone(xRange: 0.15...0.35, yRange: 0.15...0.35, count: 15, sizeRange: 38...46), "garlic"),
        (HerbZone(xRange: 0.7...0.8,   yRange: 0.15...0.35, count: 10, sizeRange: 55...70), "chives"),
        (HerbZone(xRange: 0.2...0.3,   yRange: 0.7...0.8,   count: 5,  sizeRange: 55...70), "rosemary"),
        (HerbZone(xRange: 0.65...0.85, yRange: 0.65...0.85, count: 10, sizeRange: 55...70), "basil"),
    ]

    @State private var placed: [(herb: PlacedHerb, type: String)] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(placed, id: \.herb.id) { entry in
                    herbView(type: entry.type, size: entry.herb.size)
                        .position(entry.herb.position)
                        .rotationEffect(.degrees(entry.herb.rotation))
                }
            }
            .onAppear {
                placed = zones.flatMap { item in
                    placeHerbs(zone: item.zone, in: geo.size).map { (herb: $0, type: item.type) }
                }
            }
        }
    }

    /// Returns the correct herb view for the given type identifier.
    @ViewBuilder
    func herbView(type: String, size: CGFloat) -> some View {
        switch type {
        case "garlic":   GarlicView(size: size)
        case "basil":    BasilView(size: size)
        case "chives":   ChivesView(size: size)
        case "rosemary": RosemaryView(size: size)
        default:         EmptyView()
        }
    }
}
