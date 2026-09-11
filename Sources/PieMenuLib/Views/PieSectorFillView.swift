import SwiftUI

/// Заливка сектора: Liquid Glass (macOS 26+) или непрозрачный фон на более старых системах.
struct PieSectorFillView: View {
    let startAngle: Double
    let endAngle: Double
    let innerRadius: Double
    let outerRadius: Double
    let cornerRadius: CGFloat
    /// Оттенок стекла (цвет пункта меню).
    let tintColor: Color
    /// Произведение непрозрачности меню и локальных коэффициентов (призрак, перетаскивание).
    let fillOpacityFactor: Double
    /// Настройки Liquid Glass для конкретного меню.
    let glassSettings: LiquidGlassSettings
    /// Для оверлея редактора обычно отключают, чтобы не дублировать системную реакцию на курсор.
    var interactiveGlass: Bool = true

    private var shape: PieSectorShape {
        PieSectorShape(
            startAngle: startAngle,
            endAngle: endAngle,
            innerRadius: innerRadius,
            outerRadius: outerRadius,
            cornerRadius: cornerRadius
        )
    }

    private var clampedFactor: Double {
        max(0, min(1, fillOpacityFactor))
    }

    private var tintOpacity: Double {
        max(0, min(1, glassSettings.tintOpacity))
    }

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                let tintAlpha = tintOpacity * clampedFactor
                let glass = Glass.regular.tint(tintColor.opacity(tintAlpha))
                shape
                    .fill(Color.clear)
                    .glassEffect(
                        interactiveGlass ? glass.interactive() : glass,
                        in: shape
                    )
            } else {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(tintColor.opacity(tintOpacity * clampedFactor))
                }
            }
        }
    }
}
