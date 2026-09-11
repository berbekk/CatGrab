import SwiftUI

struct PieMenuView: View {
    let items: [PieMenuItem]
    let radius: Double
    let innerRadius: Double
    let iconDistance: Double
    let iconSize: Double
    let rotationDegrees: Double
    let liquidGlass: LiquidGlassSettings
    let menuCenter: CGPoint
    var pawDecorationEnabled: Bool = true
    var pawSizeScale: Double = PieMenu.defaultPawSizeScale
    var pawRadialInset: Double = PieMenu.defaultPawRadialInset
    var centerCatScale: Double = PieMenu.defaultCenterCatScale
    var shortcutDigitSizeScale: Double = PieMenu.defaultShortcutDigitSizeScale
    var shortcutDigitInsetLeftScale: Double = PieMenu.defaultShortcutDigitInsetLeftScale
    var shortcutDigitInsetRightScale: Double = PieMenu.defaultShortcutDigitInsetRightScale
    var shortcutDigitOpacity: Double = PieMenu.defaultShortcutDigitOpacity
    var shortcutDigitColorHex: String = PieMenu.defaultShortcutDigitColorHex
    /// См. `MouseTrackingOverlay.innerCircleHighlightsFirstSector`.
    var innerCircleHighlightsFirstSector: Bool = false
    /// В полноэкранном оверлее без интерактивного стекла стабильнее отрисовка секторов (Liquid Glass).
    var sectorGlassInteractive: Bool = false
    /// Пропустить анимацию появления: меню рисуется в финальном состоянии сразу.
    /// Используется для меню «запущенные приложения», чтобы переключение между приложениями
    /// ощущалось мгновенно, без ожидания scale/opacity‑перехода.
    var appearsInstantly: Bool = false
    @ObservedObject var highlightState: PieMenuHighlightState
    var hapticFeedbackEnabled: Bool = true
    var onItemSelected: ((PieMenuItem) -> Void)?
    var onHoverChanged: ((PieMenuItem?) -> Void)?
    var onDismiss: (() -> Void)?

    @State private var appeared = false
    @State private var pointerForEyes: CGPoint = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sectorCount: Int {
        max(1, items.count)
    }

    private var resolvedShortcutLabels: [String?] {
        PieMenu.resolvedShortcutLabels(for: items)
    }

    private var sectorAngle: Double {
        (2 * .pi) / Double(sectorCount)
    }

    private var rotationRadians: Double {
        rotationDegrees * .pi / 180
    }

    private func startAngle(for index: Int) -> Double {
        PieSectorLayout.sectorAngles(
            index: index,
            sectorCount: sectorCount,
            rotationRadians: rotationRadians,
            innerRadius: innerRadius,
            outerRadius: radius
        ).start
    }

    private func endAngle(for index: Int) -> Double {
        PieSectorLayout.sectorAngles(
            index: index,
            sectorCount: sectorCount,
            rotationRadians: rotationRadians,
            innerRadius: innerRadius,
            outerRadius: radius
        ).end
    }

    /// Мордочка по `cat.svg` — прямоугольный bbox; базовый множитель с `centerCatScale`, чтобы уши не заходили в секторы.
    private var catArtDiameter: CGFloat {
        CGFloat(innerRadius * 2) * DS.Pie.centerCatArtDiameterFactor * CGFloat(PieMenu.clampedCenterCatScale(centerCatScale))
    }

    var body: some View {
        GeometryReader { geo in
            let center = menuCenter

            ZStack {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { onDismiss?() }

                ZStack {
                    let labels = resolvedShortcutLabels
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        PieSegmentView(
                            item: item,
                            shortcutLabel: index < labels.count ? labels[index] : PieMenu.quickSelectLabel(for: index),
                            isHovered: highlightState.highlightedIndex == index,
                            startAngle: startAngle(for: index),
                            endAngle: endAngle(for: index),
                            radius: radius,
                            innerRadius: innerRadius,
                            iconDistance: iconDistance,
                            iconSize: iconSize,
                            liquidGlass: liquidGlass,
                            glassInteractive: sectorGlassInteractive,
                            pawDecorationEnabled: pawDecorationEnabled,
                            pawSizeScale: pawSizeScale,
                            pawRadialInset: pawRadialInset,
                            shortcutDigitSizeScale: shortcutDigitSizeScale,
                            shortcutDigitInsetLeftScale: shortcutDigitInsetLeftScale,
                            shortcutDigitInsetRightScale: shortcutDigitInsetRightScale,
                            shortcutDigitOpacity: shortcutDigitOpacity,
                            shortcutDigitColorHex: shortcutDigitColorHex
                        )
                        .frame(width: radius * 2, height: radius * 2)
                    }
                }
                .compositingGroup()
                .scaleEffect(appeared ? 1.0 : 0.6)
                .opacity(appeared ? 1.0 : 0.0)
                .position(center)

                PieCenterCatEyesView(
                    diameter: catArtDiameter,
                    pupilOffset: PieCenterCatEyesView.lookOffset(
                        pointer: pointerForEyes,
                        hubCenter: center,
                        hubDiameter: catArtDiameter
                    )
                )
                .scaleEffect(appeared ? 1.0 : 0.6)
                .opacity(appeared ? 1.0 : 0.0)
                .position(center)
                .animation(
                    DS.Motion.respectReducing(.spring(response: 0.09, dampingFraction: 0.78), reduce: reduceMotion),
                    value: pointerForEyes
                )

                MouseTrackingOverlay(
                    center: center,
                    radius: radius,
                    innerRadius: innerRadius,
                    sectorCount: items.count,
                    rotationDegrees: rotationDegrees,
                    items: items,
                    innerCircleHighlightsFirstSector: innerCircleHighlightsFirstSector,
                    hapticFeedbackEnabled: hapticFeedbackEnabled,
                    onPointerLocationUpdate: { pointerForEyes = $0 },
                    onHover: { index in
                        if index == nil {
                            highlightState.highlightedIndex = nil
                        } else {
                            withAnimation(DS.Motion.respectReducing(.spring(response: 0.2, dampingFraction: 0.75), reduce: reduceMotion)) {
                                highlightState.highlightedIndex = index
                            }
                        }
                        let item = index.flatMap { $0 < items.count ? items[$0] : nil }
                        onHoverChanged?(item)
                    },
                    onSelect: { item in
                        onItemSelected?(item)
                    },
                    onDismiss: { onDismiss?() }
                )
            }
        }
        .ignoresSafeArea()
        .onAppear {
            pointerForEyes = menuCenter
            if appearsInstantly {
                appeared = true
            } else {
                withAnimation(DS.Motion.respectReducing(.easeOut(duration: 0.12), reduce: reduceMotion)) {
                    appeared = true
                }
            }
        }
    }
}

#Preview("PieMenu — 6 items") {
    PieMenuView(
        items: PieConfiguration.defaultConfig.menus[0].items,
        radius: 140,
        innerRadius: centerCircleRadius,
        iconDistance: 0.55,
        iconSize: 30,
        rotationDegrees: 0,
        liquidGlass: .default,
        menuCenter: CGPoint(x: 250, y: 250),
        sectorGlassInteractive: true,
        highlightState: PieMenuHighlightState()
    )
    .frame(width: 500, height: 500)
    .preferredColorScheme(.dark)
}
