import Foundation

/// Где рисовать кольцо и куда при этом деть курсор. Чистая геометрия — без окон, чтобы её можно
/// было проверить тестами.
enum PieMenuPlacement {
    /// Центр кольца в координатах окна (начало — верхний левый угол): под курсором, но так, чтобы
    /// кольцо целиком поместилось. У края экрана центр сдвигается внутрь.
    static func clampedCenter(proposed: CGPoint, radius: CGFloat, bounds: CGSize) -> CGPoint {
        func clamp(_ value: CGFloat, length: CGFloat) -> CGFloat {
            let lower = radius
            let upper = length - radius
            guard lower <= upper else { return length / 2 }
            return min(max(value, lower), upper)
        }
        return CGPoint(x: clamp(proposed.x, length: bounds.width), y: clamp(proposed.y, length: bounds.height))
    }

    /// Кольцо сдвинули от курсора — курсор переносим в его центр. Иначе у края экрана курсор
    /// оказывался бы уже внутри какого-то сектора, и привычное движение «вверх» выбирало бы не то,
    /// что в середине экрана. Совсем маленький сдвиг незаметен и переноса не стоит.
    static func needsCursorWarp(proposed: CGPoint, center: CGPoint, tolerance: CGFloat = 1) -> Bool {
        abs(proposed.x - center.x) > tolerance || abs(proposed.y - center.y) > tolerance
    }
}

extension PieSectorLayout {
    /// Стрелки на клавиатуре: сектор, чья середина ближе всего к направлению стрелки.
    /// `direction` — угол в радианах в экранных координатах (0 — вправо, `-π/2` — вверх).
    static func sectorIndex(closestToDirection direction: Double, sectorCount: Int, rotationRadians: Double) -> Int? {
        guard sectorCount > 0 else { return nil }
        let step = sectorStep(sectorCount: sectorCount)
        var bestIndex: Int?
        var bestDistance = Double.infinity
        for index in 0..<sectorCount {
            let mid = step * (Double(index) + 0.5) - .pi / 2 + rotationRadians
            var delta = abs(direction - mid).truncatingRemainder(dividingBy: 2 * .pi)
            if delta > .pi { delta = 2 * .pi - delta }
            if delta < bestDistance - 1e-9 {
                bestDistance = delta
                bestIndex = index
            }
        }
        return bestIndex
    }

    /// Следующий или предыдущий сектор по кругу; без выделения — первый или последний.
    static func cycledIndex(from current: Int?, by offset: Int, sectorCount: Int) -> Int? {
        guard sectorCount > 0 else { return nil }
        guard let current else { return offset >= 0 ? 0 : sectorCount - 1 }
        return ((current + offset) % sectorCount + sectorCount) % sectorCount
    }
}
