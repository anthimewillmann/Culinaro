import SwiftUI

// MARK: - CarrotShape

/// A bezier-curve shape approximating a carrot body (tapered oval with a rounded left end).
struct CarrotShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, mid = h / 2
        var path = Path()
        path.move(to: CGPoint(x: 0, y: mid - h * 0.25))
        path.addCurve(to: CGPoint(x: w * 0.82, y: mid - h * 0.18),
                      control1: CGPoint(x: w * 0.3,  y: mid - h * 0.35),
                      control2: CGPoint(x: w * 0.65, y: mid - h * 0.25))
        path.addCurve(to: CGPoint(x: w * 0.82, y: mid + h * 0.18),
                      control1: CGPoint(x: w * 1.05, y: mid - h * 0.1),
                      control2: CGPoint(x: w * 1.05, y: mid + h * 0.1))
        path.addCurve(to: CGPoint(x: 0, y: mid + h * 0.25),
                      control1: CGPoint(x: w * 0.65, y: mid + h * 0.25),
                      control2: CGPoint(x: w * 0.3,  y: mid + h * 0.35))
        path.addCurve(to: CGPoint(x: 0, y: mid - h * 0.25),
                      control1: CGPoint(x: -w * 0.15, y: mid + h * 0.15),
                      control2: CGPoint(x: -w * 0.15, y: mid - h * 0.15))
        path.closeSubpath()
        return path
    }
}

// MARK: - CarrotView

/// Renders a stylised carrot: an orange body with a green stem circle.
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
                .offset(x: -86)
        }
        .rotationEffect(.degrees(150))
        .scaleEffect(scale)
        .opacity(opacity)
    }
}

// MARK: - CucumberShape

/// A bezier-curve shape approximating an elongated cucumber body.
struct CucumberShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
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

/// Renders a stylised cucumber: a green body with darker end caps.
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

/// A configurable star shape with rounded corners, used as the tomato leaf silhouette.
/// - Parameters:
///   - points: Number of star points.
///   - innerRadius: Inner radius as a fraction of the outer radius.
///   - cornerRadius: Corner rounding as a fraction of the local radius.
struct StarShape: Shape {
    let points: Int
    let innerRadius: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center   = CGPoint(x: rect.midX, y: rect.midY)
        let outerR   = min(rect.width, rect.height) / 2
        let innerR   = outerR * innerRadius
        let total    = points * 2
        let step     = CGFloat.pi * 2 / CGFloat(total)
        let offset   = -CGFloat.pi / 2
        var vertices = [CGPoint]()

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
            let r    = i.isMultiple(of: 2) ? outerR : innerR
            let cr   = r * cornerRadius
            let d1   = hypot(curr.x - prev.x, curr.y - prev.y)
            let d2   = hypot(curr.x - next.x, curr.y - next.y)
            let t1   = min(cr / d1, 0.5)
            let t2   = min(cr / d2, 0.5)
            let p1   = CGPoint(x: curr.x + (prev.x - curr.x) * t1,
                               y: curr.y + (prev.y - curr.y) * t1)
            let p2   = CGPoint(x: curr.x + (next.x - curr.x) * t2,
                               y: curr.y + (next.y - curr.y) * t2)
            if i == 0 { path.move(to: p1) } else { path.addLine(to: p1) }
            path.addQuadCurve(to: p2, control: curr)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - TomatoLeafView

/// A green five-pointed star shape used as the tomato calyx (leaf crown).
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
