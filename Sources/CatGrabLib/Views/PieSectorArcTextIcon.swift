import SwiftUI
import AppKit

/// Текстовая «иконка» (`text:…`): символы вдоль дуги кольца внутри угла сектора.
/// Расстановка по реальной ширине глифов (а не по равному углу), чтобы кернинг
/// не «рвался» на буквах разной ширины.
struct PieSectorArcTextIcon: View {
    let text: String
    let center: CGPoint
    let startAngle: Double
    let endAngle: Double
    let radialDistance: CGFloat
    let baseFontSize: CGFloat
    let color: Color

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Дополнительный трекинг между глифами в долях от размера шрифта.
    private static let trackingFactor: CGFloat = 0.02
    /// Отступ от угловых границ сектора (в радианах, но не больше доли самого сектора).
    private static let angularMarginAbsolute: Double = 0.12
    private static let angularMarginSectorFraction: Double = 0.08

    var body: some View {
        let chars = Array(trimmed)
        if chars.isEmpty {
            EmptyView()
        } else {
            arcGlyphs(characters: chars)
        }
    }

    @ViewBuilder
    private func arcGlyphs(characters: [Character]) -> some View {
        let sectorSpan = endAngle - startAngle
        let margin = min(sectorSpan * Self.angularMarginSectorFraction, Self.angularMarginAbsolute)
        let a0 = startAngle + margin
        let a1 = endAngle - margin
        let angularSpan = max(0.001, a1 - a0)
        let arcLength = max(1, radialDistance * CGFloat(angularSpan))

        let layout = computeLayout(characters: characters, maxArcLength: arcLength)
        let midAngle = (a0 + a1) / 2
        let totalAngle = layout.totalLength / radialDistance
        // В нижней половине (sin > 0 в экранных координатах) переворачиваем:
        // текст идёт по дуге с другой стороны, глифы повёрнуты на -π/2,
        // чтобы строка читалась слева-направо и не висела вверх ногами.
        let flip = sin(midAngle) > 0
        let startA = flip
            ? midAngle + Double(totalAngle) / 2
            : midAngle - Double(totalAngle) / 2
        let direction: Double = flip ? -1 : 1
        let rotationOffset: Double = flip ? -.pi / 2 : .pi / 2

        ForEach(Array(characters.enumerated()), id: \.offset) { index, ch in
            let centerArc = layout.centers[index]
            let angle = startA + direction * Double(centerArc / radialDistance)
            let x = center.x + CGFloat(cos(angle)) * radialDistance
            let y = center.y + CGFloat(sin(angle)) * radialDistance
            Text(String(ch))
                .font(.system(size: layout.fontSize, weight: .semibold))
                .foregroundStyle(color)
                .rotationEffect(.radians(angle + rotationOffset))
                .position(x: x, y: y)
        }
        .allowsHitTesting(false)
    }

    private struct ArcLayout {
        let fontSize: CGFloat
        let totalLength: CGFloat
        /// Позиция центра каждого символа по длине дуги (от начала композиции).
        let centers: [CGFloat]
    }

    private func computeLayout(characters: [Character], maxArcLength: CGFloat) -> ArcLayout {
        let (widths0, total0) = glyphAdvances(characters: characters, fontSize: baseFontSize)
        let scale = total0 <= maxArcLength ? 1 : maxArcLength / total0
        var fontSize = max(7, baseFontSize * scale)
        let (widths, total) = fontSize == baseFontSize
            ? (widths0, total0)
            : glyphAdvances(characters: characters, fontSize: fontSize)
        if total > maxArcLength, total0 > 0 {
            let adjusted = max(7, fontSize * (maxArcLength / total))
            fontSize = adjusted
        }
        let (finalWidths, finalTotal) = glyphAdvances(characters: characters, fontSize: fontSize)
        _ = widths
        var centers: [CGFloat] = []
        centers.reserveCapacity(finalWidths.count)
        var cursor: CGFloat = 0
        for w in finalWidths {
            centers.append(cursor + w / 2)
            cursor += w
        }
        return ArcLayout(fontSize: fontSize, totalLength: finalTotal, centers: centers)
    }

    private func glyphAdvances(characters: [Character], fontSize: CGFloat) -> (widths: [CGFloat], total: CGFloat) {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let tracking = fontSize * Self.trackingFactor
        var widths: [CGFloat] = []
        widths.reserveCapacity(characters.count)
        var total: CGFloat = 0
        for (i, ch) in characters.enumerated() {
            let size = (String(ch) as NSString).size(withAttributes: attrs)
            let w = size.width + (i < characters.count - 1 ? tracking : 0)
            widths.append(w)
            total += w
        }
        return (widths, total)
    }
}
