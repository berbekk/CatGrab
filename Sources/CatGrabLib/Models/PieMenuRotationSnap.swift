import Foundation

extension PieMenu {
    static func normalizeRotationDegrees(_ degrees: Double) -> Double {
        var normalized = degrees
        while normalized <= -180 { normalized += 360 }
        while normalized > 180 { normalized -= 360 }
        return normalized
    }

    /// Шаг между «красивыми» положениями:
    /// - центр сектора на вертикали;
    /// - вертикаль между двумя секторами.
    static func aestheticRotationStepDegrees(for sectorCount: Int) -> Double {
        guard sectorCount > 0 else { return 360 }
        return 180 / Double(sectorCount)
    }

    static func snappedAestheticRotationDegrees(raw degrees: Double, sectorCount: Int) -> Double {
        guard sectorCount > 0 else { return normalizeRotationDegrees(degrees) }
        let step = aestheticRotationStepDegrees(for: sectorCount)
        let normalized = normalizeRotationDegrees(degrees)
        let snapped = (normalized / step).rounded() * step
        return normalizeRotationDegrees(snapped)
    }

    mutating func snapRotationToAestheticAnchor() {
        let count = items.count
        guard count > 0 else { return }
        rotationDegrees = Self.snappedAestheticRotationDegrees(
            raw: rotationDegrees,
            sectorCount: count
        )
    }
}
