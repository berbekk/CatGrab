import Foundation

/// Общая геометрия кольца: угловые зазоры между секторами и нормализация угла курсора.
enum PieSectorLayout {
    /// Полная ширина физического зазора между секторами в поинтах.
    static var gapPoints: Double {
        7
    }

    private static let minSectorSpanEpsilon: Double = 0.001

    static func normalizePointerAngle(atan2Angle: Double, rotationRadians: Double) -> Double {
        var a = atan2Angle + .pi / 2 - rotationRadians
        while a < 0 { a += 2 * .pi }
        while a >= 2 * .pi { a -= 2 * .pi }
        return a
    }

    private static func wrappedDelta(_ angle: Double) -> Double {
        var d = angle
        while d > .pi { d -= 2 * .pi }
        while d < -.pi { d += 2 * .pi }
        return d
    }

    static func sectorStep(sectorCount: Int) -> Double {
        (2 * .pi) / Double(max(1, sectorCount))
    }

    static func sectorAngles(
        index: Int,
        sectorCount: Int,
        rotationRadians: Double,
        innerRadius: Double,
        outerRadius: Double
    ) -> (start: Double, end: Double) {
        _ = innerRadius
        _ = outerRadius
        let step = sectorStep(sectorCount: sectorCount)
        let rawStart = step * Double(index) - .pi / 2 + rotationRadians
        let rawEnd = step * Double(index + 1) - .pi / 2 + rotationRadians
        return (rawStart, rawEnd)
    }

    /// true, если точка попадает в угловой зазор между секторами.
    static func isInGap(
        angleNorm: Double,
        radius: Double,
        sectorCount: Int,
        innerRadius: Double = centerCircleRadius,
        outerRadius: Double
    ) -> Bool {
        let n = max(1, sectorCount)
        guard n > 1 else { return false }
        let step = sectorStep(sectorCount: n)
        let boundaryIdx = Int((angleNorm / step).rounded())
        let boundaryAngle = Double(boundaryIdx) * step
        let delta = abs(wrappedDelta(angleNorm - boundaryAngle))
        _ = innerRadius
        _ = outerRadius
        let referenceRadius = max(1, radius)
        let clampedHalfGap = min(gapPoints / 2, referenceRadius * 0.95)
        let baseInset = asin(clampedHalfGap / referenceRadius)
        let maxInset = max(0, (step / 2) - minSectorSpanEpsilon)
        let inset = min(baseInset, maxInset)
        return delta < inset
    }

    /// Индекс сектора или `nil`, если курсор в зазоре между секторами.
    /// - Parameter ignoreAngularGaps: для hit-testing: не отбрасывать точки в узких угловых зазорах
    ///   (у внутреннего радиуса зазор «шире» по углу, из‑за чего кажется, что клик срабатывает только у внешнего края).
    static func sectorIndex(
        angleNorm: Double,
        radius: Double,
        sectorCount: Int,
        innerRadius: Double = centerCircleRadius,
        outerRadius: Double,
        ignoreAngularGaps: Bool = false
    ) -> Int? {
        let n = max(1, sectorCount)
        if n == 1 { return 0 }
        if !ignoreAngularGaps,
           isInGap(
            angleNorm: angleNorm,
            radius: radius,
            sectorCount: n,
            innerRadius: innerRadius,
            outerRadius: outerRadius
           ) { return nil }
        let step = sectorStep(sectorCount: n)
        var idx = Int(angleNorm / step)
        if idx >= n { idx = n - 1 }
        if idx < 0 { idx = 0 }
        return idx
    }
}
