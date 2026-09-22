import SwiftUI

/// Заливка сектора: Liquid Glass (macOS 26+) или непрозрачный фон на более старых системах.
///
/// Стекло при наведении не меняется вовсе — ни форма, ни тон. Любая перемена у элемента внутри
/// `GlassEffectContainer` (особенно у первого) заставляет контейнер перерисовать и заново оценить
/// всё стекло: кольцо тёмно моргало при быстрых переходах, а масштаб фигуры ещё и отставал от
/// обводки. Выделение рисуется отдельным слоем поверх (`PieSegmentView.sectorEmphasis`).
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

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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

    private var tintAlpha: Double {
        min(1, tintOpacity * clampedFactor)
    }

    var body: some View {
        Group {
            if reduceTransparency {
                // Материалы и `Glass` продолжают просвечивать рабочий стол даже с этой настройкой —
                // системная реакция на неё убирает блюр/вибранси, но не гарантирует непрозрачность.
                // Секторы держатся только на цвете, поэтому здесь заливка полностью сплошная.
                ZStack {
                    shape.fill(DS.Colors.field)
                    shape.fill(tintColor.opacity(min(1, DS.Pie.reduceTransparencyTintAlpha * clampedFactor)))
                }
            } else if #available(macOS 26.0, *) {
                // «Прозрачное» — `Glass.clear`: рабочий стол под кольцом читается сильнее.
                let base: Glass = glassSettings.variant == .clear ? .clear : .regular
                let glass = base.tint(tintColor.opacity(tintAlpha))
                shape
                    .fill(Color.clear)
                    .glassEffect(
                        interactiveGlass ? glass.interactive() : glass,
                        in: shape
                    )
            } else {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                        .opacity(glassSettings.variant == .clear ? 0.55 : 1)
                    shape.fill(tintColor.opacity(tintAlpha))
                }
            }
        }
    }
}
