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
    var centerAppIconScale: Double = PieMenu.defaultCenterAppIconScale
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
    /// Меню «Команды приложения»: команда для каждого пункта `items`, в том же порядке.
    /// `nil` — обычное меню.
    var commands: [PieSubAction]?
    /// Чьи команды показаны: иконка этого приложения встаёт в центр вместо кота.
    var commandsAppBundleId: String?
    @ObservedObject var highlightState: PieMenuHighlightState
    var hapticFeedbackEnabled: Bool = true
    var onItemSelected: ((PieMenuItem) -> Void)?
    var onCommandSelected: ((PieSubAction) -> Void)?
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

    /// Мордочка по `design/cat.svg` — прямоугольный bbox; базовый множитель с `centerCatScale`, чтобы уши не заходили в секторы.
    private var catArtDiameter: CGFloat {
        CGFloat(innerRadius * 2) * DS.Pie.centerCatArtDiameterFactor * CGFloat(PieMenu.clampedCenterCatScale(centerCatScale))
    }

    /// Иконка приложения в центре меню команд (её держит кот); размер — доля центрального круга.
    private var hubAppIconSize: CGFloat {
        CGFloat(innerRadius * 2 * PieMenu.clampedCenterAppIconScale(centerAppIconScale))
    }

    private func command(at index: Int) -> PieSubAction? {
        guard let commands, index >= 0, index < commands.count else { return nil }
        return commands[index]
    }

    /// Кольцо секторов. На macOS 26 каждый сектор — отдельный `Glass.regular`, а такое стекло адаптивно:
    /// оно само переключается между светлой и тёмной отрисовкой по яркости того, что под ним. Поодиночке
    /// секторы сэмплируют каждый свой кусок рабочего стола и через пару секунд «перещёлкиваются»
    /// вразнобой. В общем контейнере стекло сэмплирует одну область и выглядит согласованно.
    /// `spacing: 0` — чтобы соседние секторы (зазор 7 pt) не сливались в одну каплю.
    ///
    /// В контейнере лежит только стекло: общий слой стекла перекрывает всё, что стоит рядом с ним
    /// в стеке, поэтому обводки, иконки, цифры и лапки рисуются отдельным слоем поверх.
    private var sectorRing: some View {
        ZStack {
            sectorGlassLayer
            sectorViews(layer: .content)
        }
    }

    @ViewBuilder
    private var sectorGlassLayer: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 0) {
                sectorViews(layer: .glass)
            }
        } else {
            sectorViews(layer: .glass)
        }
    }

    private func sectorViews(layer: PieSegmentView.Layer) -> some View {
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
                    shortcutDigitColorHex: shortcutDigitColorHex,
                    appearsDisabled: command(at: index).map { !$0.isEnabled },
                    layer: layer
                )
                .frame(width: radius * 2, height: radius * 2)
            }
        }
    }

    /// Кот, а в меню команд — иконка приложения, чьи команды показаны.
    @ViewBuilder
    private func hub(center: CGPoint) -> some View {
        if let bundleId = commandsAppBundleId {
            let side = hubAppIconSize
            let iconCenter = CGPoint(x: center.x, y: center.y + CatHoldingAppIconView.centeringOffset(iconSide: side))
            let head = CatHoldingAppIconView.headCenterOffset(iconSide: side)
            CatHoldingAppIconView(
                bundleIdentifier: bundleId,
                iconSide: side,
                pupilOffset: PieCenterCatEyesView.lookOffset(
                    pointer: pointerForEyes,
                    hubCenter: CGPoint(x: iconCenter.x + head.width, y: iconCenter.y + head.height),
                    hubDiameter: CatHoldingAppIconView.headWidth(iconSide: side)
                )
            )
            .scaleEffect(appeared ? 1.0 : 0.6)
            .opacity(appeared ? 1.0 : 0.0)
            .position(iconCenter)
            .animation(
                DS.Motion.respectReducing(.spring(response: 0.09, dampingFraction: 0.78), reduce: reduceMotion),
                value: pointerForEyes
            )
        } else {
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
        }
    }

    /// Подпись выделенной команды снаружи кольца: значка мало, чтобы различать похожие команды.
    /// Сменяется коротким наплывом на месте, а не летает за курсором.
    private func commandLabel(bounds: CGSize) -> some View {
        ZStack {
            if let index = highlightState.highlightedIndex, let action = command(at: index) {
                PieSubActionLabel(action: action)
                    .position(
                        PieSubActionLabel.position(
                            for: action,
                            angle: (startAngle(for: index) + endAngle(for: index)) / 2,
                            ringOuterRadius: radius,
                            menuCenter: menuCenter,
                            bounds: bounds
                        )
                    )
                    .id(index)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.1), value: highlightState.highlightedIndex)
    }

    private func select(_ item: PieMenuItem) {
        guard commands != nil else {
            onItemSelected?(item)
            return
        }
        guard let index = items.firstIndex(where: { $0.id == item.id }),
              let action = command(at: index), action.isEnabled else { return }
        onCommandSelected?(action)
    }

    var body: some View {
        GeometryReader { geo in
            let center = menuCenter

            ZStack {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { onDismiss?() }

                sectorRing
                    .compositingGroup()
                    .scaleEffect(appeared ? 1.0 : 0.6)
                    .opacity(appeared ? 1.0 : 0.0)
                    .position(center)

                hub(center: center)

                if commands != nil {
                    commandLabel(bounds: geo.size)
                }

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
                        select(item)
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

#Preview("Pie menu — 6 items") {
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
