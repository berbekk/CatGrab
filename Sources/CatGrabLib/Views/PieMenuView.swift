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
    var catColorHex: String = PieMenu.defaultCatColorHex
    var pawColorHex: String = PieMenu.defaultPawColorHex
    /// См. `MouseTrackingOverlay.innerCircleHighlightsFirstSector`.
    var innerCircleHighlightsFirstSector: Bool = false
    /// В полноэкранном оверлее без интерактивного стекла стабильнее отрисовка секторов (Liquid Glass).
    var sectorGlassInteractive: Bool = false
    /// Меню «Команды приложения»: команда для каждого пункта `items`, в том же порядке.
    /// `nil` — обычное меню.
    var commands: [PieSubAction]?
    /// Чьи команды показаны: иконка этого приложения встаёт в центр вместо кота.
    var commandsAppBundleId: String?
    /// Подпись каждого пункта для показа под курсором; `nil` — подписи выключены у этого меню.
    var hoverLabels: [PieHoverLabelText?]?
    /// Секторы, которые сейчас нельзя выбрать: приглушены, клик и отпускание хоткея на них — ничего.
    var disabledIndices: Set<Int> = []
    @ObservedObject var highlightState: PieMenuHighlightState
    /// Появление и взгляд кота; в превью и на макетах — свой объект, сразу появившийся.
    @ObservedObject var presentation: PieMenuPresentation
    var hapticFeedbackEnabled: Bool = true
    var onItemSelected: ((PieMenuItem) -> Void)?
    var onCommandSelected: ((PieSubAction) -> Void)?
    var onDismiss: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var appeared: Bool { presentation.appeared }
    private var pointerForEyes: CGPoint { presentation.pointer }

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

    /// Приглушить сектор: недоступная команда или приложение, которого нет. У обычного меню `nil` —
    /// пустой сектор сам решает по действию; у меню команд пустое действие — норма, а не пустой сектор.
    private func appearsDisabled(at index: Int) -> Bool? {
        if disabledIndices.contains(index) { return true }
        return commands != nil ? false : nil
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
            // Идентичность — место в кольце, а не пункт. Дерево живёт между показами, и пункт, который
            // в этот раз стоит на другом секторе (меню запущенных приложений), должен появиться там
            // заново, а не переехать с анимацией со старого места.
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
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
                    pawColorHex: pawColorHex,
                    appearsDisabled: appearsDisabled(at: index),
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
            // Анимация взгляда стоит на самой мордочке, до позиции и масштаба: дерево живёт между
            // показами, и иначе смена центра кольца ехала бы той же пружиной — кот «прилетал» с места
            // прошлого показа.
            CatHoldingAppIconView(
                bundleIdentifier: bundleId,
                iconSide: side,
                pupilOffset: PieCenterCatEyesView.lookOffset(
                    pointer: pointerForEyes,
                    hubCenter: CGPoint(x: iconCenter.x + head.width, y: iconCenter.y + head.height),
                    hubDiameter: CatHoldingAppIconView.headWidth(iconSide: side)
                ),
                headColor: Color(hex: catColorHex) ?? .black,
                pawColor: Color(hex: pawColorHex) ?? .black
            )
            .animation(DS.Motion.respectReducing(DS.Motion.catGaze, reduce: reduceMotion), value: pointerForEyes)
            .scaleEffect(appeared ? 1.0 : DS.Pie.entranceScale)
            .opacity(appeared ? 1.0 : 0.0)
            .position(iconCenter)
        } else {
            PieCenterCatEyesView(
                diameter: catArtDiameter,
                pupilOffset: PieCenterCatEyesView.lookOffset(
                    pointer: pointerForEyes,
                    hubCenter: center,
                    hubDiameter: catArtDiameter
                ),
                headColor: Color(hex: catColorHex) ?? .black
            )
            .animation(DS.Motion.respectReducing(DS.Motion.catGaze, reduce: reduceMotion), value: pointerForEyes)
            .scaleEffect(appeared ? 1.0 : DS.Pie.entranceScale)
            .opacity(appeared ? 1.0 : 0.0)
            .position(center)
        }
    }

    /// Подпись выделенного сектора снаружи кольца: название и что выполнится. Значка мало, чтобы
    /// различать похожие секторы. Сменяется коротким наплывом на месте, а не летает за курсором.
    private func hoverLabel(bounds: CGSize) -> some View {
        ZStack {
            if let index = highlightState.highlightedIndex, let label = hoverLabelView(at: index) {
                label
                    .position(
                        label.position(
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

    private func hoverLabelView(at index: Int) -> PieHoverLabel? {
        guard let hoverLabels, index >= 0, index < items.count else { return nil }
        if let action = command(at: index) {
            return PieHoverLabel(action: action)
        }
        guard index < hoverLabels.count, let text = hoverLabels[index] else { return nil }
        return PieHoverLabel(text: text, isEnabled: !disabledIndices.contains(index))
    }

    private func select(_ item: PieMenuItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }),
              !disabledIndices.contains(index) else { return }
        guard commands != nil else {
            onItemSelected?(item)
            return
        }
        guard let action = command(at: index), action.isEnabled else { return }
        onCommandSelected?(action)
    }

    var body: some View {
        GeometryReader { geo in
            let center = menuCenter

            ZStack {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { onDismiss?() }

                // Без `compositingGroup`: группа рисовала бы стекло за кадром при каждой смене
                // обводки или лапки; за 100 мс появления раздельная прозрачность слоёв незаметна.
                sectorRing
                    .scaleEffect(appeared ? 1.0 : DS.Pie.entranceScale)
                    .opacity(appeared ? 1.0 : 0.0)
                    .position(center)

                hub(center: center)

                if hoverLabels != nil {
                    hoverLabel(bounds: geo.size)
                }

                MouseTrackingOverlay(
                    center: center,
                    radius: radius,
                    innerRadius: innerRadius,
                    sectorCount: items.count,
                    rotationDegrees: rotationDegrees,
                    items: items,
                    innerCircleHighlightsFirstSector: innerCircleHighlightsFirstSector,
                    onPointerLocationUpdate: { presentation.pointer = $0 },
                    onHover: { index in
                        // Уход с сектора — той же пружиной, что и вход: без транзакции стекло прыгало
                        // бы к исходному размеру мгновенно, а обводка ещё четверть секунды сжималась.
                        withAnimation(DS.Motion.respectReducing(DS.Motion.sectorHighlight, reduce: reduceMotion)) {
                            highlightState.select(index, hapticFeedbackEnabled: index != nil && hapticFeedbackEnabled)
                        }
                    },
                    onSelect: { item in
                        select(item)
                    },
                    onDismiss: { onDismiss?() }
                )
            }
        }
        .ignoresSafeArea()
    }
}

extension PieMenuPresentation {
    /// Для превью: кольцо уже на месте.
    static func settled(pointer: CGPoint) -> PieMenuPresentation {
        let presentation = PieMenuPresentation()
        presentation.appeared = true
        presentation.pointer = pointer
        return presentation
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
        hoverLabels: PieConfiguration.defaultConfig.menus[0].items.map { $0.hoverLabel(language: .english) },
        highlightState: PieMenuHighlightState(),
        presentation: .settled(pointer: CGPoint(x: 250, y: 250))
    )
    .frame(width: 500, height: 500)
    .preferredColorScheme(.dark)
}
