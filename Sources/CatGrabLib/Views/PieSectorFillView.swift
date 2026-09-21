import SwiftUI

/// Заливка сектора: Liquid Glass (macOS 26+) или непрозрачный фон на более старых системах.
struct PieSectorFillView: View, Animatable {
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
    /// Увеличение сектора при наведении. Масштабируется сама фигура, а не view: внутри
    /// `GlassEffectContainer` стекло строится по фигуре и не видит `.scaleEffect` предков —
    /// обводка увеличивалась, а стекло оставалось на месте.
    var scale: CGFloat = 1

    /// Через `Animatable` SwiftUI пересчитывает `body` на каждом кадре пружины,
    /// и стекло получает промежуточную фигуру, а не прыгает сразу к конечному размеру.
    var animatableData: CGFloat {
        get { scale }
        set { scale = newValue }
    }

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Фигура строится вокруг центра кольца (`rect.mid`), поэтому масштаб от `.center`
    /// совпадает с прежним `.scaleEffect` на кадре сектора.
    private var shape: ScaledShape<PieSectorShape> {
        PieSectorShape(
            startAngle: startAngle,
            endAngle: endAngle,
            innerRadius: innerRadius,
            outerRadius: outerRadius,
            cornerRadius: cornerRadius
        )
        .scale(scale)
    }

    private var clampedFactor: Double {
        max(0, min(1, fillOpacityFactor))
    }

    private var tintOpacity: Double {
        max(0, min(1, glassSettings.tintOpacity))
    }

    var body: some View {
        Group {
            if reduceTransparency {
                // Материалы и `Glass` продолжают просвечивать рабочий стол даже с этой настройкой —
                // системная реакция на неё убирает блюр/вибранси, но не гарантирует непрозрачность.
                // Секторы держатся только на цвете, поэтому здесь заливка полностью сплошная.
                ZStack {
                    shape.fill(DS.Colors.field)
                    shape.fill(tintColor.opacity(DS.Pie.reduceTransparencyTintAlpha * clampedFactor))
                }
            } else if #available(macOS 26.0, *) {
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
