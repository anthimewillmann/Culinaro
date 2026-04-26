//
//  WaveAnimation.swift
//  Culinaro
//
//  Created by Anthime Willmann on 25.04.26.
//

import SwiftUI

// MARK: - Bubble
struct Bubble: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var delay: Double
}

// MARK: - BubbleView
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

// MARK: - WiggleModifier
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
                            width: CGFloat.random(in: -xAmount...xAmount),
                            height: CGFloat.random(in: -yAmount...yAmount)
                        )
                    }
                }
            }
    }
}

extension View {
    func wiggle(x: CGFloat = 6, y: CGFloat = 6, duration: Double = 1.2) -> some View {
        modifier(WiggleModifier(xAmount: x, yAmount: y, duration: duration))
    }
}

// MARK: - CarrotShape
struct CarrotShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let mid = h / 2
        var path = Path()
        path.move(to: CGPoint(x: 0, y: mid - h * 0.25))
        path.addCurve(
            to: CGPoint(x: w * 0.82, y: mid - h * 0.18),
            control1: CGPoint(x: w * 0.3, y: mid - h * 0.35),
            control2: CGPoint(x: w * 0.65, y: mid - h * 0.25)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.82, y: mid + h * 0.18),
            control1: CGPoint(x: w * 1.05, y: mid - h * 0.1),
            control2: CGPoint(x: w * 1.05, y: mid + h * 0.1)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: mid + h * 0.25),
            control1: CGPoint(x: w * 0.65, y: mid + h * 0.25),
            control2: CGPoint(x: w * 0.3, y: mid + h * 0.35)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: mid - h * 0.25),
            control1: CGPoint(x: -w * 0.15, y: mid + h * 0.15),
            control2: CGPoint(x: -w * 0.15, y: mid - h * 0.15)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - CarrotView
struct CarrotView: View {
    var scale: CGFloat
    var opacity: CGFloat
    var body: some View {
        ZStack {
            CarrotShape()
                .fill(Color(red: 1.0, green: 0.72, blue: 0.35))
                .frame(width: 150, height: 65)
            Circle()
                .fill(Color(red: 0.24, green: 0.65, blue: 0.24))
                .frame(width: 22, height: 22)
                .offset(x: -86, y: 0)
        }
        .rotationEffect(.degrees(150))
        .scaleEffect(scale)
        .opacity(opacity)
    }
}

// MARK: - CucumberShape
struct CucumberShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.08, y: 0))
        path.addCurve(to: CGPoint(x: w * 0.92, y: 0),
                      control1: CGPoint(x: w * 0.3, y: -h * 0.15),
                      control2: CGPoint(x: w * 0.7, y: -h * 0.15))
        path.addCurve(to: CGPoint(x: w * 0.92, y: h),
                      control1: CGPoint(x: w * 1.1, y: 0),
                      control2: CGPoint(x: w * 1.1, y: h))
        path.addCurve(to: CGPoint(x: w * 0.08, y: h),
                      control1: CGPoint(x: w * 0.7, y: h * 1.15),
                      control2: CGPoint(x: w * 0.3, y: h * 1.15))
        path.addCurve(to: CGPoint(x: w * 0.08, y: 0),
                      control1: CGPoint(x: -w * 0.1, y: h),
                      control2: CGPoint(x: -w * 0.1, y: 0))
        path.closeSubpath()
        return path
    }
}

// MARK: - CucumberView
struct CucumberView: View {
    var scale: CGFloat
    var opacity: CGFloat
    var body: some View {
        ZStack {
            CucumberShape()
                .fill(Color(red: 0.4, green: 0.78, blue: 0.4))
                .frame(width: 280, height: 56)
            Circle()
                .fill(Color(red: 0.18, green: 0.5, blue: 0.18))
                .frame(width: 18, height: 18)
                .offset(x: -154)
            Circle()
                .fill(Color(red: 0.18, green: 0.5, blue: 0.18))
                .frame(width: 18, height: 18)
                .offset(x: 154)
        }
        .rotationEffect(.degrees(-15))
        .scaleEffect(scale)
        .opacity(opacity)
    }
}

// MARK: - StarShape
struct StarShape: Shape {
    let points: Int
    let innerRadius: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = min(rect.width, rect.height) / 2
        let innerR = outerR * innerRadius
        let total  = points * 2
        let step   = CGFloat.pi * 2 / CGFloat(total)
        let offset = -CGFloat.pi / 2
        var vertices: [CGPoint] = []
        for i in 0..<total {
            let angle = offset + step * CGFloat(i)
            let r = i.isMultiple(of: 2) ? outerR : innerR
            vertices.append(CGPoint(x: center.x + cos(angle) * r,
                                    y: center.y + sin(angle) * r))
        }
        var path = Path()
        for i in 0..<total {
            let prev = vertices[(i - 1 + total) % total]
            let curr = vertices[i]
            let next = vertices[(i + 1) % total]
            let r = i.isMultiple(of: 2) ? outerR : innerR
            let cr = r * cornerRadius
            let d1 = hypot(curr.x - prev.x, curr.y - prev.y)
            let d2 = hypot(curr.x - next.x, curr.y - next.y)
            let t1 = min(cr / d1, 0.5)
            let t2 = min(cr / d2, 0.5)
            let p1 = CGPoint(x: curr.x + (prev.x - curr.x) * t1,
                             y: curr.y + (prev.y - curr.y) * t1)
            let p2 = CGPoint(x: curr.x + (next.x - curr.x) * t2,
                             y: curr.y + (next.y - curr.y) * t2)
            if i == 0 { path.move(to: p1) } else { path.addLine(to: p1) }
            path.addQuadCurve(to: p2, control: curr)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - TomatoLeafView
struct TomatoLeafView: View {
    let scale: CGFloat
    let opacity: CGFloat
    var body: some View {
        StarShape(points: 5, innerRadius: 0.25, cornerRadius: 0.35)
            .fill(Color(red: 0.25, green: 0.75, blue: 0.25))
            .frame(width: 120 * scale, height: 120 * scale)
            .opacity(opacity)
    }
}

// MARK: - Suppen-Scheiben
struct CucumberSliceView: View {
    var size: CGFloat = 80
    var body: some View {
        ZStack {
            Circle().fill(Color(red: 0.85, green: 0.96, blue: 0.78))
            Circle().fill(Color(red: 0.72, green: 0.91, blue: 0.60))
                .frame(width: size * 0.62, height: size * 0.62)
        }
        .frame(width: size, height: size)
    }
}

struct TomatoSliceView: View {
    var size: CGFloat = 90
    var body: some View {
        ZStack {
            Circle().fill(Color(red: 0.96, green: 0.63, blue: 0.63))
            Circle().fill(Color(red: 0.98, green: 0.82, blue: 0.82))
                .frame(width: size * 0.58, height: size * 0.58)
        }
        .frame(width: size, height: size)
    }
}

struct MushroomSliceView: View {
    var capSize: CGFloat = 60
    var stemWidth: CGFloat = 34
    var stemHeight: CGFloat = 34
    var body: some View {
        let capColor = Color(red: 0.88, green: 0.82, blue: 0.67)
        VStack(spacing: -8) {
            Circle().fill(capColor).frame(width: capSize, height: capSize)
            RoundedRectangle(cornerRadius: 5).fill(capColor)
                .frame(width: stemWidth, height: stemHeight)
        }
    }
}

// MARK: - Kräuter
let herbColor = Color(red: 0.72, green: 0.91, blue: 0.60)

struct HerbZone {
    var xRange: ClosedRange<CGFloat>
    var yRange: ClosedRange<CGFloat>
    var count: Int
    var sizeRange: ClosedRange<CGFloat>
}

struct PlacedHerb: Identifiable {
    let id = UUID()
    let position: CGPoint
    let rotation: Double
    let size: CGFloat
}

func placeHerbs(zone: HerbZone, in canvasSize: CGSize) -> [PlacedHerb] {
    let cols = Int(ceil(sqrt(Double(zone.count))))
    let rows = Int(ceil(Double(zone.count) / Double(cols)))
    let xStep = (zone.xRange.upperBound - zone.xRange.lowerBound) / CGFloat(max(cols - 1, 1))
    let yStep = (zone.yRange.upperBound - zone.yRange.lowerBound) / CGFloat(max(rows - 1, 1))
    var result: [PlacedHerb] = []
    for row in 0..<rows {
        for col in 0..<cols {
            guard result.count < zone.count else { break }
            let x = canvasSize.width  * (zone.xRange.lowerBound + CGFloat(col) * xStep)
            let y = canvasSize.height * (zone.yRange.lowerBound + CGFloat(row) * yStep)
            result.append(PlacedHerb(
                position: CGPoint(x: x + CGFloat.random(in: -8...8),
                                  y: y + CGFloat.random(in: -8...8)),
                rotation: Double.random(in: -30...30),
                size: CGFloat.random(in: zone.sizeRange)
            ))
        }
    }
    return result
}

struct GarlicView: View {
    var size: CGFloat = 48
    var body: some View {
        Circle().stroke(herbColor, lineWidth: 6)
            .frame(width: size * 0.6, height: size * 0.6)
    }
}

struct BasilView: View {
    var size: CGFloat = 48
    var body: some View {
        let w = size * 0.6; let h = size * 0.95
        let cx = size / 2; let top = (size - h) / 2; let bottom = (size + h) / 2
        return Path { p in
            p.move(to: CGPoint(x: cx, y: top))
            p.addQuadCurve(to: CGPoint(x: cx, y: bottom), control: CGPoint(x: cx + w, y: size / 2))
            p.addQuadCurve(to: CGPoint(x: cx, y: top),   control: CGPoint(x: cx - w, y: size / 2))
        }
        .fill(herbColor).frame(width: size, height: size)
    }
}

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

struct RosemaryView: View {
    var size: CGFloat = 48
    var body: some View {
        let positions: [CGFloat] = [0.10, 0.25, 0.42, 0.58, 0.74, 0.88]
        return ZStack {
            Path { p in
                p.move(to: CGPoint(x: size / 2, y: size * 1.2))
                p.addLine(to: CGPoint(x: size / 2, y: size * -0.2))
            }
            .stroke(herbColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
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

// MARK: - SoupLayoutPreview (Kräuter-Endszene)
struct SoupLayoutPreview: View {
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

// MARK: - WaveShape
struct WaveShape: Shape {
    var t: CGFloat
    var expand: CGFloat
    var waveRise: CGFloat
    private let baseYScale: CGFloat = 0.63
    private let expandYScaleBonus: CGFloat = 0.54
    private let pathHeight: CGFloat = 180
    private let pathWidth: CGFloat = 100

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(t, expand), waveRise) }
        set { t = newValue.first.first; expand = newValue.first.second; waveRise = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        func lerp(_ a: CGFloat, _ b: CGFloat, _ v: CGFloat = -1) -> CGFloat {
            let factor = v < 0 ? t : v; return a + (b - a) * factor
        }
        let leftX = 20 * (1 - expand)
        let rightX = 80 + 20 * expand
        let scaleYFactor = baseYScale + expandYScaleBonus * expand
        let riseOffset = (1 - waveRise) * rect.height * 0.55
        var path = Path()
        path.move(to: CGPoint(x: leftX, y: 0 + riseOffset / (rect.height / pathHeight)))
        path.addCurve(to: CGPoint(x: leftX, y: pathHeight),
                      control1: CGPoint(x: lerp(50, -10) * (1 - expand) - 10 * expand, y: 60),
                      control2: CGPoint(x: lerp(-10, 50) * (1 - expand) - 10 * expand, y: 120))
        path.addLine(to: CGPoint(x: rightX, y: pathHeight))
        path.addCurve(to: CGPoint(x: rightX, y: 0 + riseOffset / (rect.height / pathHeight)),
                      control1: CGPoint(x: lerp(50, 110) * (1 - expand) + 110 * expand, y: 120),
                      control2: CGPoint(x: lerp(110, 50) * (1 - expand) + 110 * expand, y: 60))
        path.closeSubpath()
        let scaleX = rect.width / pathWidth
        let scaleY = rect.height * scaleYFactor / pathHeight
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY).translatedBy(x: 0, y: riseOffset / scaleY)
        return path.applying(transform)
    }
}

// MARK: - AnimationPhase
enum AnimationPhase {
    case intro, waveRising, wave, expanding, bubbles, finale, blackHole
}

// MARK: - WaveAnimationView
struct WaveAnimationView: View {

    @State private var grayRise: CGFloat = 0
    @State private var waveRise: CGFloat = 0
    @State private var t: CGFloat = 0
    @State private var expand: CGFloat = 0
    @State private var showBubbles: Bool = false
    @State private var hideBubbles: Bool = false
    @State private var finalBubbleScale: CGFloat = 0
    @State private var finalBubbleOpacity: CGFloat = 0
    @State private var finalBubbleWhiteFill: CGFloat = 0
    @State private var finalBubbleWhiteOpacity: CGFloat = 1
    @State private var blackOverlayOpacity: CGFloat = 0
    @State private var blackHoleScale: CGFloat = 1.0
    @State private var beigeHoleScale: CGFloat = 1.0
    @State private var beigeOverlayOpacity: CGFloat = 0
    @State private var backgroundIsBeige: Bool = false
    @State private var hideWaveAndGray: Bool = false
    @State private var leafScale: CGFloat = 0
    @State private var leafOpacity: CGFloat = 0
    @State private var tomatoZoomScale: CGFloat = 1.0
    @State private var tomatoOffset: CGSize = .zero
    @State private var sceneZoom: CGFloat = 1.0
    @State private var sceneOffset: CGSize = .zero
    @State private var carrotScale: CGFloat = 0
    @State private var carrotOpacity: CGFloat = 0
    @State private var carrotOffset: CGSize = CGSize(width: -200, height: 0)
    @State private var carrot2Scale: CGFloat = 0
    @State private var carrot2Opacity: CGFloat = 0
    @State private var carrot2Offset: CGSize = CGSize(width: -200, height: 0)
    @State private var cucumberScale: CGFloat = 0
    @State private var cucumberOpacity: CGFloat = 0
    @State private var cucumberOffset: CGSize = CGSize(width: 200, height: 0)
    @State private var tomato2Scale: CGFloat = 1
    @State private var tomato2Opacity: CGFloat = 0
    @State private var tomato2Offset: CGSize = CGSize(width: -220, height: 0)
    @State private var tomato3Scale: CGFloat = 1
    @State private var tomato3Opacity: CGFloat = 0
    @State private var tomato3Offset: CGSize = CGSize(width: 0, height: 220)
    @State private var soupIngredientsOpacity: CGFloat = 0
    @State private var soupSceneZoom: CGFloat = 1.0
    @State private var soupSceneOffset: CGSize = .zero
    @State private var herbsOpacity: CGFloat = 0
    @State private var showHerbsScene: Bool = false
    @State private var herbsDropOffset: CGFloat = 0
    @State private var herbsDropOpacity: CGFloat = 1
    @State private var slideUpOffset: CGFloat = 0
    @State private var showOnlyHerbs: Bool = false
    @State private var beigeTransitionOpacity: CGFloat = 0
    @State private var beigeTransitionOffset: CGFloat = 0
    @State private var grayRise2: CGFloat = 0
    @State private var herbsDropOpacity2: CGFloat = 1

    let finalBubbleSize: CGFloat = 160
    let grayColor = Color(red: 0.9, green: 0.9, blue: 0.9)
    private let smallTomatoRatio: CGFloat = 0.5
    private var smallLeafScale: CGFloat { smallTomatoRatio * 0.75 }

    let bubbles: [Bubble] = (0..<9).map { i in
        Bubble(x: CGFloat.random(in: 0.15...0.85),
               y: CGFloat.random(in: 0.15...0.85),
               delay: Double(i) * 0.5)
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            GeometryReader { geo in
                ZStack {

                    // ── Layer 1: Beiger Vollflächenhintergrund ─────────────
                    if backgroundIsBeige {
                        Color(red: 0.96, green: 0.91, blue: 0.80).ignoresSafeArea()
                    }

                    // ── Layer 2: Gesamte Animations-Szene ─────────────────
                    if !showOnlyHerbs {
                        ZStack {
                            ZStack {
                                ZStack(alignment: .bottom) {
                                    if !hideWaveAndGray {
                                        WaveShape(t: t, expand: expand, waveRise: waveRise)
                                            .fill(Color(red: 0.85, green: 0.95, blue: 1.0))
                                            .frame(width: geo.size.width, height: geo.size.height)
                                            .ignoresSafeArea()
                                            .opacity(waveRise > 0 ? 1 : 0)
                                            .onAppear { startAnimationSequence(geo: geo) }

                                        let restY = geo.size.height * 0.52
                                        let introOffset = (1 - grayRise) * geo.size.height
                                        let expandOffset = geo.size.height * 0.55 * expand
                                        Rectangle()
                                            .fill(grayColor)
                                            .frame(height: restY)
                                            .frame(maxWidth: .infinity)
                                            .ignoresSafeArea(edges: .bottom)
                                            .padding(.bottom, -50)
                                            .offset(y: introOffset + expandOffset)
                                    }
                                }

                                if showBubbles {
                                    ForEach(bubbles) { bubble in
                                        BubbleView(x: bubble.x, y: bubble.y, delay: bubble.delay,
                                                   geo: geo, hide: hideBubbles)
                                    }
                                }

                                if finalBubbleWhiteOpacity > 0 && finalBubbleOpacity > 0 {
                                    Circle()
                                        .fill(Color(UIColor.systemBackground))
                                        .frame(width: finalBubbleWhiteFill, height: finalBubbleWhiteFill)
                                        .opacity(finalBubbleOpacity * finalBubbleWhiteOpacity)
                                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                                }

                                if blackOverlayOpacity > 0 {
                                    GeometryReader { innerGeo in
                                        Rectangle().fill(Color.black).ignoresSafeArea()
                                            .mask(
                                                ZStack {
                                                    Rectangle().fill(Color.black)
                                                    Circle()
                                                        .frame(width: blackHoleScale + 10, height: blackHoleScale + 10)
                                                        .position(x: innerGeo.size.width / 2, y: innerGeo.size.height * 0.5)
                                                        .blendMode(.destinationOut)
                                                }
                                                .compositingGroup()
                                            )
                                            .opacity(blackOverlayOpacity)
                                    }
                                    .ignoresSafeArea()
                                }

                                if beigeOverlayOpacity > 0 {
                                    GeometryReader { innerGeo in
                                        Rectangle()
                                            .fill(Color(red: 0.96, green: 0.91, blue: 0.80))
                                            .ignoresSafeArea()
                                            .mask(
                                                ZStack {
                                                    Rectangle().fill(Color.black)
                                                    Circle()
                                                        .frame(width: beigeHoleScale + 10, height: beigeHoleScale + 10)
                                                        .position(x: innerGeo.size.width / 2, y: innerGeo.size.height * 0.5)
                                                        .blendMode(.destinationOut)
                                                }
                                                .compositingGroup()
                                            )
                                            .opacity(beigeOverlayOpacity)
                                    }
                                    .ignoresSafeArea()
                                }

                                // ── Haupt-Tomate ───────────────────────────
                                ZStack {
                                    Circle().fill(Color.red)
                                        .frame(width: finalBubbleScale, height: finalBubbleScale)
                                    Circle().strokeBorder(grayColor, lineWidth: 5)
                                        .frame(width: finalBubbleScale, height: finalBubbleScale)
                                        .opacity(finalBubbleScale < finalBubbleSize * 1.1 ? 1 : 0)
                                    TomatoLeafView(scale: leafScale, opacity: leafOpacity)
                                }
                                .opacity(finalBubbleOpacity)
                                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                                .scaleEffect(tomatoZoomScale)
                                .offset(tomatoOffset)

                                // ── Kleine Tomate 2 ────────────────────────
                                ZStack {
                                    Circle().fill(Color.red)
                                        .frame(width: finalBubbleSize * smallTomatoRatio,
                                               height: finalBubbleSize * smallTomatoRatio)
                                    TomatoLeafView(scale: smallLeafScale, opacity: 1)
                                }
                                .scaleEffect(tomato2Scale).opacity(tomato2Opacity).offset(tomato2Offset)
                                .position(x: geo.size.width * 0.18, y: geo.size.height * 0.78)

                                // ── Kleine Tomate 3 ────────────────────────
                                ZStack {
                                    Circle().fill(Color.red)
                                        .frame(width: finalBubbleSize * smallTomatoRatio,
                                               height: finalBubbleSize * smallTomatoRatio)
                                    TomatoLeafView(scale: smallLeafScale, opacity: 1)
                                }
                                .scaleEffect(tomato3Scale).opacity(tomato3Opacity).offset(tomato3Offset)
                                .position(x: geo.size.width * 0.5, y: geo.size.height * 0.82)

                                CarrotView(scale: carrotScale, opacity: carrotOpacity)
                                    .rotationEffect(.degrees(230)).offset(carrotOffset)
                                    .position(x: geo.size.width * 0.32, y: geo.size.height * 0.22)

                                CarrotView(scale: carrot2Scale, opacity: carrot2Opacity)
                                    .rotationEffect(.degrees(220)).offset(carrot2Offset)
                                    .position(x: geo.size.width * 0.4, y: geo.size.height * 0.12)

                                CucumberView(scale: cucumberScale, opacity: cucumberOpacity)
                                    .rotationEffect(.degrees(90)).offset(cucumberOffset)
                                    .position(x: geo.size.width * 0.78, y: geo.size.height * 0.54)
                            }
                            .scaleEffect(sceneZoom)
                            .offset(sceneOffset)

                            // ── Suppen-Zutaten-Szene ───────────────────────
                            if backgroundIsBeige {
                                ZStack {
                                    BubbleView(x: 0.25, y: 0.25, delay: 0.0, geo: geo, hide: false)
                                        .opacity(soupIngredientsOpacity)
                                    BubbleView(x: 0.30, y: 0.65, delay: 1.5, geo: geo, hide: false)
                                        .opacity(soupIngredientsOpacity)
                                    BubbleView(x: 0.75, y: 0.75, delay: 0.8, geo: geo, hide: false)
                                        .opacity(soupIngredientsOpacity)

                                    CucumberSliceView(size: 120).wiggle().opacity(soupIngredientsOpacity)
                                        .position(x: geo.size.width * 0.80, y: geo.size.height * 0.60)
                                    CucumberSliceView(size: 120).wiggle().opacity(soupIngredientsOpacity)
                                        .position(x: geo.size.width * 0.60, y: geo.size.height * 0.20)

                                    TomatoSliceView(size: 135).wiggle().opacity(soupIngredientsOpacity)
                                        .position(x: geo.size.width * 0.35, y: geo.size.height * 0.85)
                                    TomatoSliceView(size: 135).wiggle().opacity(soupIngredientsOpacity)
                                        .position(x: geo.size.width * 0.40, y: geo.size.height * 0.45)

                                    GarlicView(size: 40).wiggle().opacity(soupIngredientsOpacity)
                                        .position(x: geo.size.width * 0.85, y: geo.size.height * 0.08)
                                    GarlicView(size: 42).wiggle().opacity(soupIngredientsOpacity)
                                        .position(x: geo.size.width * 0.80, y: geo.size.height * 0.38)
                                    GarlicView(size: 44).wiggle().opacity(soupIngredientsOpacity)
                                        .position(x: geo.size.width * 0.15, y: geo.size.height * 0.25)
                                    GarlicView(size: 40).wiggle().opacity(soupIngredientsOpacity)
                                        .position(x: geo.size.width * 0.30, y: geo.size.height * 0.65)

                                    MushroomSliceView(capSize: 75, stemWidth: 34, stemHeight: 28).wiggle().opacity(soupIngredientsOpacity)
                                        .position(x: geo.size.width * 0.20, y: geo.size.height * 0.10)
                                    MushroomSliceView(capSize: 75, stemWidth: 34, stemHeight: 28).wiggle().opacity(soupIngredientsOpacity)
                                        .position(x: geo.size.width * 0.85, y: geo.size.height * 0.85)
                                }
                                .scaleEffect(soupSceneZoom)
                                .offset(soupSceneOffset)
                            }
                        }
                        .offset(y: slideUpOffset)
                    }

                    // ── Layer 3: Beiges Übergangs-Overlay ─────────────────
                    if beigeTransitionOpacity > 0 {
                        Color(red: 0.96, green: 0.91, blue: 0.80).ignoresSafeArea()
                            .opacity(beigeTransitionOpacity)
                            .offset(y: beigeTransitionOffset)
                            .allowsHitTesting(false)
                    }

                    // ── Layer 4: Kräuter-Szene ─────────────────────────────
                    if showHerbsScene {
                        SoupLayoutPreview()
                            .opacity(herbsOpacity)
                            .offset(y: herbsDropOffset)
                    }

                    // ── Layer 5: Zweite graue Fläche ───────────────────────
                    VStack {
                        Spacer()
                        let restY = geo.size.height * 0.52
                        let introOffset = (1 - grayRise2) * geo.size.height
                        Rectangle().fill(grayColor)
                            .frame(height: restY).frame(maxWidth: .infinity)
                            .padding(.bottom, -50)
                            .offset(y: introOffset)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        }
    }

    // MARK: - Animationssequenz
    private func startAnimationSequence(geo: GeometryProxy) {

        // ── Schritt 1: Graue Fläche fährt von unten hoch ──────────────────
        // Startet sofort beim Erscheinen der View – nur einmal, nicht im Loop
        withAnimation(.easeOut(duration: 2.5)) { grayRise = 1 }

        Task { @MainActor in
            while true {

                // ── Schritt 2: Blaue Welle erscheint & beginnt zu oszillieren ─
                try? await Task.sleep(for: .seconds(2.0))
                withAnimation(.easeOut(duration: 4.0)) { waveRise = 1 }
                withAnimation(.easeInOut(duration: 3.25).repeatForever(autoreverses: true)) { t = 1 }

                // ── Schritt 3: Welle weitet sich aus (Expansion) ──────────────
                try? await Task.sleep(for: .seconds(7.5))
                withAnimation(.easeInOut(duration: 2.5)) { expand = 1 }

                // ── Schritt 4: Kleine Blasen erscheinen ───────────────────────
                try? await Task.sleep(for: .seconds(2.0))
                showBubbles = true

                // ── Schritt 5: Kleine Blasen verschwinden ─────────────────────
                try? await Task.sleep(for: .seconds(8.0))
                withAnimation(.easeOut(duration: 1.0)) { hideBubbles = true }

                // ── Schritt 6: Große Tomate-Blase wächst auf ──────────────────
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeIn(duration: 3.7)) { finalBubbleOpacity = 1 }
                withAnimation(.easeInOut(duration: 1.5)) { finalBubbleScale = finalBubbleSize }
                withAnimation(.easeInOut(duration: 6.0)) {
                    finalBubbleWhiteFill = max(geo.size.width, geo.size.height) * 2.5
                }

                // ── Schritt 7: Black-Hole-Effekt ──────────────────────────────
                try? await Task.sleep(for: .seconds(4.0))
                blackHoleScale = max(geo.size.width, geo.size.height) * 2.5
                withAnimation(.easeIn(duration: 0.2)) { blackOverlayOpacity = 1 }
                withAnimation(.easeInOut(duration: 3.5)) { blackHoleScale = finalBubbleSize - 10 }

                // ── Schritt 8: Tomate wird größer → Übergang zum Beige ────────
                try? await Task.sleep(for: .seconds(4.0))
                withAnimation(.easeInOut(duration: 2.5)) { blackHoleScale = finalBubbleSize * 1.5 - 20 }
                withAnimation(.easeInOut(duration: 2.5)) { finalBubbleScale = finalBubbleSize * 1.5 }

                // ── Schritt 9: Beiger Hintergrund & beiges Overlay mit Loch ───
                try? await Task.sleep(for: .seconds(2.5))
                backgroundIsBeige = true
                hideWaveAndGray = true
                withAnimation(.easeIn(duration: 0.3).delay(3.5)) { finalBubbleWhiteOpacity = 0 }
                beigeHoleScale = max(geo.size.width, geo.size.height) * 2.5
                withAnimation(.easeIn(duration: 0.3)) { beigeOverlayOpacity = 1 }
                withAnimation(.easeInOut(duration: 3.5)) { beigeHoleScale = finalBubbleSize * 1.5 - 20 }
                withAnimation(.easeOut(duration: 1.8).delay(1.5)) { leafOpacity = 1; leafScale = 1 }

                // ── Schritt 10: Tomate schrumpft → Gemüse-Phase beginnt ───────
                try? await Task.sleep(for: .seconds(4.0))
                blackOverlayOpacity = 0
                withAnimation(.easeInOut(duration: 2.0)) {
                    tomatoZoomScale = 0.38
                    tomatoOffset = CGSize(width: -geo.size.width * 0.15, height: geo.size.height * 0.17)
                    beigeOverlayOpacity = 0
                }
                withAnimation(.easeOut(duration: 1.5).delay(0.4)) {
                    carrotScale = 1; carrotOpacity = 1; carrotOffset = .zero
                }
                withAnimation(.easeOut(duration: 1.5).delay(0.7)) {
                    carrot2Scale = 1; carrot2Opacity = 1; carrot2Offset = .zero
                }
                withAnimation(.easeOut(duration: 1.5).delay(0.8)) {
                    cucumberScale = 1; cucumberOpacity = 1; cucumberOffset = .zero
                }
                withAnimation(.easeOut(duration: 1.2).delay(0.5)) { tomato2Opacity = 1; tomato2Offset = .zero }
                withAnimation(.easeOut(duration: 1.2).delay(0.9)) { tomato3Opacity = 1; tomato3Offset = .zero }

                // ── Schritt 11: Zoom in Karotte 1 ────────────────────────────
                try? await Task.sleep(for: .seconds(4.0))
                let targetX = geo.size.width * 0.32
                let targetY = geo.size.height * 0.22
                let centerX = geo.size.width / 2
                let centerY = geo.size.height / 2
                let zoomFactor: CGFloat = 50.0
                withAnimation(.easeIn(duration: 5.0)) {
                    sceneZoom = zoomFactor
                    sceneOffset = CGSize(width: (centerX - targetX) * zoomFactor,
                                        height: (centerY - targetY) * zoomFactor)
                }

                // ── Schritt 12: Suppen-Zutaten einblenden ────────────────────
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeIn(duration: 2.0)) { soupIngredientsOpacity = 1 }

                // ── Schritt 13: Zoom in Gurkenscheibe ────────────────────────
                try? await Task.sleep(for: .seconds(8.0))
                let gurkeX = geo.size.width * 0.80
                let gurkeY = geo.size.height * 0.60
                let gurkeZoom: CGFloat = 50.0
                withAnimation(.easeInOut(duration: 5.0)) {
                    soupSceneZoom = gurkeZoom
                    soupSceneOffset = CGSize(width: (geo.size.width / 2 - gurkeX) * gurkeZoom,
                                            height: (geo.size.height / 2 - gurkeY) * gurkeZoom)
                }

                // ── Schritt 14: Beiges Overlay + Kräuter einblenden ──────────
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.easeInOut(duration: 3.5)) { beigeTransitionOpacity = 1.0 }
                showHerbsScene = true
                withAnimation(.easeIn(duration: 3.0).delay(0.5)) { herbsOpacity = 1.0 }

                // ── Schritt 15: Aufräumen hinter dem Overlay ─────────────────
                try? await Task.sleep(for: .seconds(3.7))
                slideUpOffset = -geo.size.height
                showOnlyHerbs = true
                backgroundIsBeige = false

                // ── Schritt 16: Beige-Overlay nach oben rausschieben ─────────
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation(.easeInOut(duration: 2.5)) { beigeTransitionOffset = -geo.size.height }
                try? await Task.sleep(for: .seconds(2.5))
                beigeTransitionOpacity = 0
                beigeTransitionOffset = 0

                // ── Schritt 17: Zweite graue Fläche fährt von unten hoch ──────
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation(.easeOut(duration: 2.5)) { grayRise2 = 1 }

                // ── Schritt 18: Kräuter fallen nach unten raus ────────────────
                try? await Task.sleep(for: .seconds(4.0))
                withAnimation(.easeIn(duration: 1.8)) { herbsDropOffset = geo.size.height * 0.6 }

                // ── Loop-Reset ────────────────────────────────────────────────
                try? await Task.sleep(for: .seconds(1.8))
                waveRise = 0; t = 0; expand = 0
                showBubbles = false; hideBubbles = false
                finalBubbleScale = 0; finalBubbleOpacity = 0
                finalBubbleWhiteFill = 0; finalBubbleWhiteOpacity = 1
                blackOverlayOpacity = 0; blackHoleScale = 1.0
                beigeHoleScale = 1.0; beigeOverlayOpacity = 0
                backgroundIsBeige = false; hideWaveAndGray = false
                leafScale = 0; leafOpacity = 0
                tomatoZoomScale = 1.0; tomatoOffset = .zero
                sceneZoom = 1.0; sceneOffset = .zero
                carrotScale = 0; carrotOpacity = 0; carrotOffset = CGSize(width: -200, height: 0)
                carrot2Scale = 0; carrot2Opacity = 0; carrot2Offset = CGSize(width: -200, height: 0)
                cucumberScale = 0; cucumberOpacity = 0; cucumberOffset = CGSize(width: 200, height: 0)
                tomato2Scale = 1; tomato2Opacity = 0; tomato2Offset = CGSize(width: -220, height: 0)
                tomato3Scale = 1; tomato3Opacity = 0; tomato3Offset = CGSize(width: 0, height: 220)
                soupIngredientsOpacity = 0; soupSceneZoom = 1.0; soupSceneOffset = .zero
                herbsOpacity = 0; showHerbsScene = false; herbsDropOffset = 0; herbsDropOpacity = 1
                slideUpOffset = 0; showOnlyHerbs = false
                beigeTransitionOpacity = 0; beigeTransitionOffset = 0
                herbsDropOpacity2 = 1; grayRise2 = 0

                try? await Task.sleep(for: .seconds(0.1))
                // → while true springt zurück zu Schritt 2
            }
        }
    }
}

#Preview {
    WaveAnimationView()
}
