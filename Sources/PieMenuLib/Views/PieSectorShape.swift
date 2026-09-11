import SwiftUI

struct PieSectorShape: Shape {
    var startAngle: Double
    var endAngle: Double
    var innerRadius: Double
    var outerRadius: Double
    var cornerRadius: CGFloat

    init(
        startAngle: Double,
        endAngle: Double,
        innerRadius: Double = 0,
        outerRadius: Double,
        cornerRadius: CGFloat = 0
    ) {
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.cornerRadius = cornerRadius
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let ri = CGFloat(innerRadius)
        let ro = CGFloat(outerRadius)
        let fullCircle = 2 * Double.pi
        let angleSpan = abs(endAngle - startAngle)
        let isFullCircle = abs(angleSpan - fullCircle) < 0.0001

        if isFullCircle {
            return fullDonutPath(center: center, ri: ri, ro: ro, startAngle: startAngle, fullCircle: fullCircle)
        }

        if innerRadius > 0, cornerRadius > 0.5,
           let rounded = roundedAnnularSectorPath(
            center: center,
            ri: ri,
            ro: ro,
            startAngle: startAngle,
            endAngle: endAngle,
            cornerRadius: cornerRadius
           ) {
            return rounded
        }

        return sharpAnnularSectorPath(
            center: center,
            ri: ri,
            ro: ro,
            startAngle: startAngle,
            endAngle: endAngle,
            innerRadius: innerRadius
        )
    }

    private func fullDonutPath(
        center: CGPoint,
        ri: CGFloat,
        ro: CGFloat,
        startAngle: Double,
        fullCircle: Double
    ) -> Path {
        var path = Path()
        let startOuter = CGPoint(
            x: center.x + CGFloat(cos(startAngle)) * ro,
            y: center.y + CGFloat(sin(startAngle)) * ro
        )
        path.move(to: startOuter)
        path.addArc(
            center: center,
            radius: ro,
            startAngle: .radians(startAngle),
            endAngle: .radians(startAngle + fullCircle),
            clockwise: false
        )
        path.closeSubpath()

        if ri > 0 {
            let startInner = CGPoint(
                x: center.x + CGFloat(cos(startAngle + fullCircle)) * ri,
                y: center.y + CGFloat(sin(startAngle + fullCircle)) * ri
            )
            path.move(to: startInner)
            path.addArc(
                center: center,
                radius: ri,
                startAngle: .radians(startAngle + fullCircle),
                endAngle: .radians(startAngle),
                clockwise: true
            )
            path.closeSubpath()
        }
        return path
    }

    private func sharpAnnularSectorPath(
        center: CGPoint,
        ri: CGFloat,
        ro: CGFloat,
        startAngle: Double,
        endAngle: Double,
        innerRadius: Double
    ) -> Path {
        var path = Path()
        if innerRadius > 0 {
            let halfGap = min(PieSectorLayout.gapPoints / 2, Double(ri) * 0.95)
            let startInsetInner = safeAsin(halfGap / Double(ri))
            let startInsetOuter = safeAsin(halfGap / Double(ro))
            let aInnerStart = startAngle + startInsetInner
            let aInnerEnd = endAngle - startInsetInner
            let aOuterStart = startAngle + startInsetOuter
            let aOuterEnd = endAngle - startInsetOuter

            guard aInnerEnd > aInnerStart + 0.0001, aOuterEnd > aOuterStart + 0.0001 else {
                return path
            }

            let a = point(center: center, radius: ri, angle: aInnerStart)
            let b = point(center: center, radius: ro, angle: aOuterStart)
            let d = point(center: center, radius: ri, angle: aInnerEnd)

            path.move(to: a)
            path.addLine(to: b)
            path.addArc(
                center: center,
                radius: ro,
                startAngle: .radians(aOuterStart),
                endAngle: .radians(aOuterEnd),
                clockwise: false
            )
            path.addLine(to: d)
            path.addArc(
                center: center,
                radius: ri,
                startAngle: .radians(aInnerEnd),
                endAngle: .radians(aInnerStart),
                clockwise: true
            )
        } else {
            path.move(to: center)
            path.addArc(
                center: center,
                radius: ro,
                startAngle: .radians(startAngle),
                endAngle: .radians(endAngle),
                clockwise: false
            )
        }
        path.closeSubpath()
        return path
    }

    private func roundedAnnularSectorPath(
        center: CGPoint,
        ri: CGFloat,
        ro: CGFloat,
        startAngle: Double,
        endAngle: Double,
        cornerRadius: CGFloat
    ) -> Path? {
        guard endAngle - startAngle > 0.001 else { return nil }

        let halfGap = min(PieSectorLayout.gapPoints / 2, Double(ri) * 0.95)
        let startInsetInner = safeAsin(halfGap / Double(ri))
        let startInsetOuter = safeAsin(halfGap / Double(ro))
        let aInnerStart = startAngle + startInsetInner
        let aInnerEnd = endAngle - startInsetInner
        let aOuterStart = startAngle + startInsetOuter
        let aOuterEnd = endAngle - startInsetOuter
        guard aInnerEnd > aInnerStart + 0.0001, aOuterEnd > aOuterStart + 0.0001 else { return nil }

        let a = point(center: center, radius: ri, angle: aInnerStart)
        let b = point(center: center, radius: ro, angle: aOuterStart)
        let c = point(center: center, radius: ro, angle: aOuterEnd)
        let d = point(center: center, radius: ri, angle: aInnerEnd)

        let startSide = b - a
        let endSide = c - d
        let startSideLen = startSide.length
        let endSideLen = endSide.length
        guard startSideLen > 0.001, endSideLen > 0.001 else { return nil }

        let startDir = startSide / startSideLen
        let endDir = endSide / endSideLen
        let innerSpan = aInnerEnd - aInnerStart
        let outerSpan = aOuterEnd - aOuterStart
        let maxByInnerArc = CGFloat(innerSpan * Double(ri) * 0.5)
        let maxByOuterArc = CGFloat(outerSpan * Double(ro) * 0.5)
        let cr = min(
            cornerRadius,
            (ro - ri) * 0.42,
            startSideLen * 0.45,
            endSideLen * 0.45,
            maxByInnerArc,
            maxByOuterArc
        )
        guard cr > 0.5 else { return nil }

        let crInner = cr * min(1, ri / ro)

        let trimOuter = min(Double(cr) / Double(ro), outerSpan * 0.45)
        let trimInner = min(Double(crInner) / Double(ri), innerSpan * 0.45)
        let trimSideOuter = min(cr, startSideLen * 0.45, endSideLen * 0.45)
        let trimSideInner = min(crInner, startSideLen * 0.45, endSideLen * 0.45)
        guard trimInner > 0, trimOuter > 0, trimSideOuter > 0 else { return nil }

        let pAStartSide = a + startDir * trimSideInner
        let pBStartSide = b - startDir * trimSideOuter
        let pBOuter = point(center: center, radius: ro, angle: aOuterStart + trimOuter)
        let pCEndSide = c - endDir * trimSideOuter
        let pDEndSide = d + endDir * trimSideInner
        let pDInner = point(center: center, radius: ri, angle: aInnerEnd - trimInner)

        var path = Path()
        path.move(to: pAStartSide)
        path.addLine(to: pBStartSide)
        path.addQuadCurve(to: pBOuter, control: b)

        path.addArc(
            center: center,
            radius: ro,
            startAngle: .radians(aOuterStart + trimOuter),
            endAngle: .radians(aOuterEnd - trimOuter),
            clockwise: false
        )
        path.addQuadCurve(to: pCEndSide, control: c)
        path.addLine(to: pDEndSide)
        path.addQuadCurve(to: pDInner, control: d)
        path.addArc(
            center: center,
            radius: ri,
            startAngle: .radians(aInnerEnd - trimInner),
            endAngle: .radians(aInnerStart + trimInner),
            clockwise: true
        )
        path.addQuadCurve(to: pAStartSide, control: a)

        path.closeSubpath()
        return path
    }

    private func safeAsin(_ value: Double) -> Double {
        asin(max(-1, min(1, value)))
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y + CGFloat(sin(angle)) * radius
        )
    }
}

private extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }

    var length: CGFloat {
        sqrt(x * x + y * y)
    }
}

#Preview("PieSectorShape") {
    ZStack {
        PieSectorShape(
            startAngle: -.pi / 2,
            endAngle: .pi / 6,
            innerRadius: 28,
            outerRadius: 120,
            cornerRadius: 12
        )
        .fill(.blue.opacity(0.3))
        .overlay(
            PieSectorShape(
                startAngle: -.pi / 2,
                endAngle: .pi / 6,
                innerRadius: 28,
                outerRadius: 120,
                cornerRadius: 12
            )
            .stroke(.blue, lineWidth: 1)
        )
    }
    .frame(width: 300, height: 300)
    .preferredColorScheme(.dark)
}
