import SwiftUI
import AppKit

struct MenuPreviewView: View {
    @Binding var menu: PieMenu
    @Binding var selectedItemId: UUID?
    var hapticFeedbackEnabled: Bool
    var isAppearancePanelVisible: Bool
    /// Клик по коту в центре: новый пункт (у меню команд — список, что добавить).
    var onAddItem: (() -> Void)?
    /// Набор команд одного приложения (`menu` — меню команд этого набора): в центре — само приложение.
    var appSetBundleId: String?
    @EnvironmentObject private var localizer: LocalizationStore

    @State private var draggedItemId: UUID?
    @State private var dragAngle: Double = 0
    @State private var dragStartAngle: Double = 0
    @State private var dragStartSectorIndex: Int = 0

    @State private var isRotatingWheel = false
    @State private var rotationAnchorMenuDegrees: Double = 0
    @State private var rotationAnchorPointerAngle: Double = 0
    @State private var lastRotationSnapForHaptic: Double?
    @State private var lastReorderHapticSlot: Int?

    private static let ghostItems: [PieMenuItem] = [
        PieMenuItem(title: "One", icon: "star.fill", action: .openURL(url: ""), color: "#007AFF", sectorIndex: 0),
        PieMenuItem(title: "Two", icon: "bolt.fill", action: .openURL(url: ""), color: "#34C759", sectorIndex: 1),
        PieMenuItem(title: "Three", icon: "music.note", action: .openURL(url: ""), color: "#FF2D55", sectorIndex: 2),
        PieMenuItem(title: "Four", icon: "folder.fill", action: .openURL(url: ""), color: "#FF9500", sectorIndex: 3)
    ]

    private var realItems: [PieMenuItem] {
        menu.items.sorted { $0.sectorIndex < $1.sectorIndex }
    }

    /// Актуальный список для меню «запущенные приложения» (предпросмотр и жесты).
    private var liveRunningAppsItems: [PieMenuItem] {
        RunningAppsMenuItems.build(for: menu)
    }

    /// Приложение для иконки в центре превью меню команд: то, из которого пришли в настройки
    /// (сейчас активен сам CatGrab), иначе Finder — он запущен всегда.
    private var previewAppBundleId: String {
        appSetBundleId ?? PieSubActionResolver.targetApp()?.bundleIdentifier ?? "com.apple.finder"
    }

    private var isAppSet: Bool {
        appSetBundleId != nil
    }

    /// Секторы в цветах меню — так же, как их покажет само кольцо.
    private var previewItems: [PieMenuItem] {
        menu.themed(sourceItems)
    }

    private var sourceItems: [PieMenuItem] {
        if menu.isRunningAppsMenu {
            return liveRunningAppsItems.isEmpty ? Self.ghostItems : liveRunningAppsItems
        }
        if menu.isAppCommandsMenu {
            return AppCommandsMenuItems.previewItems(entries: menu.appCommandsDefaultEntries)
        }
        return menu.items.isEmpty ? Self.ghostItems : realItems
    }

    /// Секторы, которые можно переставлять перетаскиванием: пункты обычного меню или команды по умолчанию
    /// меню команд. В меню запущенных приложений порядок задают сами приложения.
    private var reorderableItems: [PieMenuItem] {
        switch menu.kind {
        case .standard: return realItems
        case .appCommands: return previewItems
        case .runningApps: return []
        }
    }

    private var previewSectorCount: Int {
        max(1, previewItems.count)
    }

    private var sectorAngle: Double {
        (2 * .pi) / Double(previewSectorCount)
    }

    private var rotationRadians: Double {
        menu.rotationDegrees * .pi / 180
    }

    private func isOptionKeyDown() -> Bool {
        NSEvent.modifierFlags.contains(.option)
    }

    private func applyWheelRotation(fingerLocation: CGPoint, cx: CGFloat, cy: CGFloat) {
        let currentAngle = atan2(Double(fingerLocation.y - cy), Double(fingerLocation.x - cx))
        var delta = currentAngle - rotationAnchorPointerAngle
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        let raw = rotationAnchorMenuDegrees + delta * 180 / .pi
        let snapped = PieMenu.snappedAestheticRotationDegrees(
            raw: raw,
            sectorCount: previewSectorCount
        )
        menu.rotationDegrees = snapped
        if let prev = lastRotationSnapForHaptic {
            if abs(prev - snapped) > 0.001 {
                if hapticFeedbackEnabled {
                    NSHapticFeedbackManager.defaultPerformer.perform(
                        .alignment,
                        performanceTime: .default
                    )
                }
                lastRotationSnapForHaptic = snapped
            }
        } else {
            lastRotationSnapForHaptic = snapped
        }
    }

    private var displayRadius: Double { menu.effectiveMenuRadius }
    private var contentSize: CGFloat { displayRadius * 2 + 30 }
    private func startAngle(for index: Int) -> Double {
        PieSectorLayout.sectorAngles(
            index: index,
            sectorCount: previewSectorCount,
            rotationRadians: rotationRadians,
            innerRadius: menu.effectiveInnerRadius,
            outerRadius: displayRadius
        ).start
    }

    private func endAngle(for index: Int) -> Double {
        PieSectorLayout.sectorAngles(
            index: index,
            sectorCount: previewSectorCount,
            rotationRadians: rotationRadians,
            innerRadius: menu.effectiveInnerRadius,
            outerRadius: displayRadius
        ).end
    }

    private func absoluteSectorIndex(from angle: Double, radiusAtPoint: Double) -> Int? {
        let n = max(1, previewItems.count)
        let angleNorm = PieSectorLayout.normalizePointerAngle(atan2Angle: angle, rotationRadians: rotationRadians)
        return PieSectorLayout.sectorIndex(
            angleNorm: angleNorm,
            radius: radiusAtPoint,
            sectorCount: n,
            innerRadius: menu.effectiveInnerRadius,
            outerRadius: displayRadius
        )
    }

    private func reorderDropIndex(for angle: Double) -> Int {
        let n = max(1, previewSectorCount)
        var delta = angle - dragStartAngle
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        let offset = Int(round(delta / sectorAngle))
        return ((dragStartSectorIndex + offset) % n + n) % n
    }

    private var dropIndex: Int {
        reorderDropIndex(for: dragAngle)
    }

    private func displayItemsDuringDrag(dropIndex: Int) -> [PieMenuItem] {
        var sorted = previewItems
        guard let id = draggedItemId,
              let fromPos = sorted.firstIndex(where: { $0.id == id }),
              fromPos != dropIndex,
              dropIndex < sorted.count else { return sorted }
        sorted.swapAt(fromPos, dropIndex)
        return sorted
    }

    @State private var hoveredSectorIndex: Int?
    /// Последний сектор под курсором — лапка остаётся на нём, когда курсор уходит с кольца,
    /// вместо того чтобы прыгать на первый сектор.
    @State private var lastPawSectorIndex = 0
    @State private var isCenterHovered = false
    @State private var showsHints = false
    /// Фон «светлый | тёмный» под превью и где между ними граница — общие для всех меню.
    @AppStorage("previewBackdropEnabled") private var showsBackdrop = false
    @AppStorage("previewBackdropSplit") private var backdropSplit = 0.5
    /// Для глаз кота в превью; `nil` — взгляд в центр (как без наведения).
    @State private var pointerForCatEyes: CGPoint?

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if showsBackdrop {
                    PreviewBackdrop(split: backdropSplit)
                }

                wheelCanvas

                if showsBackdrop {
                    PreviewBackdropHandle(split: $backdropSplit)
                }

                // Подсказки — по кнопке: текстом поверх превью на них наезжали секторы крупного кольца.
                HStack(alignment: .top, spacing: DS.Spacing.s) {
                    hintsButton
                    PreviewToolbarButton(
                        icon: "circle.lefthalf.filled",
                        isActive: showsBackdrop,
                        help: localizer.text(.previewBackdropHelp)
                    ) {
                        showsBackdrop.toggle()
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, DS.Spacing.s)
                .padding(.top, DS.Spacing.s)
            }
            .frame(maxHeight: .infinity)

            Spacer(minLength: 0)

            Group {
                if menu.isRunningAppsMenu {
                    if liveRunningAppsItems.isEmpty {
                        Text(localizer.text(.runningAppsEmptyPreview))
                            .multilineTextAlignment(.center)
                    }
                } else if !menu.isDynamicMenu && menu.items.isEmpty {
                    Text(localizer.text(.addFirstItemHint))
                        .multilineTextAlignment(.center)
                }
            }
            .font(DS.Typography.label)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, DS.Spacing.m)
        }
    }

    private var wheelCanvas: some View {
        GeometryReader { geo in
            let scale = min(1.0, geo.size.width / contentSize, geo.size.height / contentSize)
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let drawRadius = displayRadius * scale
            let drawInnerRadius = menu.effectiveInnerRadius * scale
            let drawIconDist = drawInnerRadius + (drawRadius - drawInnerRadius) * menu.iconDistance
            let drawCornerRadius = min(CGFloat(DS.Pie.sectorCornerRadius) * scale, CGFloat(drawRadius * 0.11))
            let currentDropIndex = dropIndex
            let itemsToShow = draggedItemId != nil
                ? displayItemsDuringDrag(dropIndex: currentDropIndex)
                : previewItems
            let isGhost: Bool = {
                switch menu.kind {
                case .runningApps: return liveRunningAppsItems.isEmpty
                case .appCommands: return false
                case .standard: return menu.items.isEmpty
                }
            }()
            let resolvedLabels = PieMenu.resolvedShortcutLabels(for: itemsToShow)
            /// Сектор с лапкой: под курсором — как в живом меню; иначе выбранный, а без выбора —
            /// там же, где лапка была до того, как курсор ушёл с кольца (не прыгает на первый).
            let pawPreviewSectorIndex: Int = {
                if let hovered = hoveredSectorIndex, hovered < itemsToShow.count {
                    return hovered
                }
                if let sid = selectedItemId,
                   let idx = itemsToShow.firstIndex(where: { $0.id == sid }) {
                    return idx
                }
                return min(lastPawSectorIndex, max(0, itemsToShow.count - 1))
            }()
            // Одна и та же лапка меняет положение, а не пересоздаётся в другом секторе на каждый
            // ховер: иначе перекрёстное появление/исчезание старой и новой лапки на быстром движении
            // мыши между секторами мелькает чёрным (тень лапки поверх тени лапки).
            let pawRingWidth = max(1, drawRadius - drawInnerRadius)
            let pawSizeRatio = PieMenu.clampedPawSizeScale(menu.pawSizeScale) / PieMenu.defaultPawSizeScale
            let pawSize = max(6, pawRingWidth * CGFloat(PieMenu.pawSizeBaseFromRingWidth) * CGFloat(pawSizeRatio))
            let pawDist = PieMenu.pawRadialDistanceFromMenuCenter(
                pawRadialInset: menu.pawRadialInset,
                outerRadius: Double(drawRadius)
            )

            ZStack {
                glassLayer(
                    items: itemsToShow,
                    innerRadius: drawInnerRadius,
                    outerRadius: drawRadius,
                    cornerRadius: drawCornerRadius
                )
                .animation(DS.Motion.sectorHighlight, value: hoveredSectorIndex)

                Group {
                    ForEach(Array(itemsToShow.enumerated()), id: \.element.id) { index, item in
                        let segmentColor = Color(hex: item.color) ?? .accentColor
                        let iconTint: Color = {
                            if let hex = item.iconColor, let c = Color(hex: hex) { return c }
                            return segmentColor
                        }()
                        let isDraggingThis = draggedItemId == item.id
                        let isSelected = !isGhost && selectedItemId == item.id
                        let isHovered = hoveredSectorIndex == index && !isDraggingThis
                        let slotStart = startAngle(for: index)
                        let slotEnd = endAngle(for: index)
                        let halfSector = sectorAngle / 2
                        let drawStart = isDraggingThis ? dragAngle - halfSector : slotStart
                        let drawEnd = isDraggingThis ? dragAngle + halfSector : slotEnd
                        let sectorShape = PieSectorShape(
                            startAngle: drawStart,
                            endAngle: drawEnd,
                            innerRadius: drawInnerRadius,
                            outerRadius: drawRadius,
                            cornerRadius: drawCornerRadius
                        )
                        let midAngle = isDraggingThis ? dragAngle : (slotStart + slotEnd) / 2
                        let ringWidth = max(1, drawRadius - drawInnerRadius)
                        let shortcutSizeRatio =
                            PieMenu.clampedShortcutDigitSizeScale(menu.shortcutDigitSizeScale)
                            / PieMenu.defaultShortcutDigitSizeScale
                        let shortcutFontSize = max(
                            6,
                            ringWidth
                                * CGFloat(PieMenu.shortcutDigitFontBaseFromRingWidth)
                                * CGFloat(shortcutSizeRatio)
                        )
                        let shortcutCorner = CGPoint(
                            x: cx + cos(drawStart) * drawRadius,
                            y: cy + sin(drawStart) * drawRadius
                        )
                        let shortcutInsetLeftRatio =
                            PieMenu.clampedShortcutDigitInsetLeftScale(menu.shortcutDigitInsetLeftScale)
                            / PieMenu.defaultShortcutDigitInsetLeftScale
                        let shortcutInsetRightRatio =
                            PieMenu.clampedShortcutDigitInsetRightScale(menu.shortcutDigitInsetRightScale)
                            / PieMenu.defaultShortcutDigitInsetRightScale
                        let shortcutRadialInset = max(
                            4,
                            ringWidth
                                * CGFloat(PieMenu.shortcutDigitInsetLeftBaseFromRingWidth)
                                * CGFloat(shortcutInsetLeftRatio)
                        )
                        let shortcutTangentialInset = max(
                            4,
                            ringWidth
                                * CGFloat(PieMenu.shortcutDigitInsetRightBaseFromRingWidth)
                                * CGFloat(shortcutInsetRightRatio)
                        )
                        let shortcutRadial = CGVector(dx: cos(drawStart), dy: sin(drawStart))
                        let shortcutTangent = CGVector(dx: -sin(drawStart), dy: cos(drawStart))
                        let shortcutPosition = CGPoint(
                            x: shortcutCorner.x - shortcutRadial.dx * shortcutRadialInset + shortcutTangent.dx * shortcutTangentialInset,
                            y: shortcutCorner.y - shortcutRadial.dy * shortcutRadialInset + shortcutTangent.dy * shortcutTangentialInset
                        )
                        let shortcutColor = Color(hex: menu.shortcutDigitColorHex) ?? .white
                        let isUnassignedSlot = !isGhost && item.action == .unassigned
                        let borderDim = isUnassignedSlot ? DS.Pie.unassignedSectorBorderOpacityMultiplier : 1.0
                        let iconRender = CGFloat(menu.fittedIconSize(sectorCount: previewSectorCount)) * scale
                            + (isHovered ? CGFloat(DS.Pie.highlightIconGrowth) : 0)

                        ZStack {
                            Group {
                                // Как в самом кольце: цвет выделения — слоем поверх неизменного стекла.
                                sectorShape.fill(
                                    segmentColor.opacity(isHovered || isSelected ? DS.Pie.highlightTintBoost : 0)
                                )
                                sectorShape.fill(
                                    RadialGradient(
                                        colors: isHovered
                                            ? [Color.white.opacity(DS.Pie.highlightInnerGlowOpacity), .clear]
                                            : [.clear, .clear],
                                        center: .center,
                                        startRadius: drawInnerRadius,
                                        endRadius: drawRadius
                                    )
                                )
                                sectorShape.stroke(
                                    Color.white.opacity(
                                        (isSelected ? DS.Pie.highlightBorderOpacity :
                                            isHovered ? DS.Pie.highlightBorderOpacity :
                                            isGhost ? 0.2 : 0.26) * borderDim
                                    ),
                                    lineWidth: (isSelected || isHovered) ? DS.Pie.highlightBorderWidth : 0.7
                                )
                                sectorShape.stroke(
                                    Color.black.opacity(
                                        (isSelected ? 0.34 :
                                            isHovered ? 0.28 :
                                            isGhost ? 0.16 : 0.18) * borderDim
                                    ),
                                    lineWidth: (isSelected || isHovered) ? DS.Pie.highlightBorderWidth : 0.7
                                )
                            }

                            Group {
                                if item.icon.hasPrefix("text:") {
                                    PieSectorArcTextIcon(
                                        text: String(item.icon.dropFirst(5)),
                                        center: CGPoint(x: cx, y: cy),
                                        startAngle: drawStart,
                                        endAngle: drawEnd,
                                        radialDistance: drawIconDist,
                                        baseFontSize: max(iconRender * DS.PieIconVisualScale.textFontToCell, 9),
                                        color: iconTint
                                    )
                                } else {
                                    IconView(
                                        icon: item.icon,
                                        size: iconRender,
                                        color: iconTint,
                                        appBundleId: item.action.bundleIdentifier
                                    )
                                    .frame(width: iconRender, height: iconRender)
                                    .position(
                                        x: cx + cos(midAngle) * drawIconDist,
                                        y: cy + sin(midAngle) * drawIconDist
                                    )
                                }
                            }
                            .shadow(
                                color: isHovered ? iconTint.opacity(0.5 * (isUnassignedSlot ? DS.Pie.unassignedIconOpacity : 1)) : .clear,
                                radius: 8,
                                x: 0,
                                y: 0
                            )
                            .opacity(isGhost ? 0.18 : (isUnassignedSlot ? DS.Pie.unassignedIconOpacity : 1))

                            if let shortcutLabel = (index < resolvedLabels.count ? resolvedLabels[index] : PieMenu.quickSelectLabel(for: index)) {
                                let shortcutInnerOpacity = PieMenu.clampedShortcutDigitOpacity(menu.shortcutDigitOpacity)
                                    * (isUnassignedSlot ? DS.Pie.unassignedShortcutBadgeOpacityMultiplier : 1)
                                Text(shortcutLabel)
                                    .font(.system(size: shortcutFontSize, weight: .medium, design: .rounded))
                                    .monospaced()
                                    .foregroundStyle(shortcutColor.opacity(shortcutInnerOpacity))
                                    .position(x: shortcutPosition.x, y: shortcutPosition.y)
                                    .opacity(isGhost ? 0.22 : 1)
                            }

                        }
                        .zIndex(isDraggingThis ? 1 : 0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                    }
                }

                // Лапка у каждого сектора, как в самом кольце: появляется на месте, а не скользит
                // от соседа. Без наведения держится на выбранном или последнем секторе — по ней
                // настраивают размер и положение лапки в «Параметрах».
                if menu.pawDecorationEnabled, draggedItemId == nil {
                    ForEach(Array(itemsToShow.enumerated()), id: \.element.id) { index, _ in
                        let isPawHere = index == pawPreviewSectorIndex
                        let midAngle = (startAngle(for: index) + endAngle(for: index)) / 2
                        CatPawGrabView(
                            size: pawSize,
                            grabProgress: isPawHere ? 1 : 0,
                            pawColor: (Color(hex: menu.pawColorHex) ?? .black).opacity(0.96)
                        )
                        .rotationEffect(.radians(midAngle + .pi / 2))
                        .scaleEffect(isPawHere ? 1 : 0.84)
                        .opacity(isPawHere ? (isGhost ? 0.85 : 1) : 0)
                        .position(
                            x: cx + cos(midAngle) * pawDist,
                            y: cy + sin(midAngle) * pawDist
                        )
                        .animation(DS.Motion.sectorHighlight, value: isPawHere)
                        .allowsHitTesting(false)
                    }
                }

                // Подпись под курсором — как в самом кольце: по ней видно, что выключает переключатель
                // в «Параметрах», и как читаются названия секторов.
                if menu.showsHoverLabel, draggedItemId == nil, !isGhost,
                   let hovered = hoveredSectorIndex, hovered < itemsToShow.count,
                   let text = previewHoverLabel(for: itemsToShow[hovered], at: hovered) {
                    let label = PieHoverLabel(text: text)
                    label
                        .position(
                            label.position(
                                angle: (startAngle(for: hovered) + endAngle(for: hovered)) / 2,
                                ringOuterRadius: Double(drawRadius),
                                menuCenter: CGPoint(x: cx, y: cy),
                                bounds: geo.size
                            )
                        )
                        .id(hovered)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }

                if menu.isAppCommandsMenu {
                    // Как в самом меню: кот держит иконку приложения, чьи команды показаны.
                    let side = drawInnerRadius * 2 * CGFloat(PieMenu.clampedCenterAppIconScale(menu.centerAppIconScale))
                    let iconCenter = CGPoint(x: cx, y: cy + CatHoldingAppIconView.centeringOffset(iconSide: side))
                    let head = CatHoldingAppIconView.headCenterOffset(iconSide: side)
                    CatHoldingAppIconView(
                        bundleIdentifier: previewAppBundleId,
                        iconSide: side,
                        pupilOffset: PieCenterCatEyesView.lookOffset(
                            pointer: pointerForCatEyes ?? iconCenter,
                            hubCenter: CGPoint(x: iconCenter.x + head.width, y: iconCenter.y + head.height),
                            hubDiameter: CatHoldingAppIconView.headWidth(iconSide: side)
                        ),
                        headColor: Color(hex: menu.catColorHex) ?? .black,
                        pawColor: Color(hex: menu.pawColorHex) ?? .black
                    )
                    .position(iconCenter)
                    .animation(.easeOut(duration: 0.14), value: menu.centerAppIconScale)
                    .allowsHitTesting(false)
                } else {
                    // Кот в центре, как в самом меню; клик по нему добавляет пункт.
                    let hubCenter = CGPoint(x: cx, y: cy)
                    let catDiam =
                        drawInnerRadius * 2
                        * DS.Pie.centerCatArtDiameterFactor
                        * CGFloat(PieMenu.clampedCenterCatScale(menu.centerCatScale))
                    PieCenterCatEyesView(
                        diameter: catDiam,
                        pupilOffset: PieCenterCatEyesView.lookOffset(
                            pointer: pointerForCatEyes ?? hubCenter,
                            hubCenter: hubCenter,
                            hubDiameter: catDiam
                        ),
                        headColor: Color(hex: menu.catColorHex) ?? .black
                    )
                    .scaleEffect(isCenterHovered && onAddItem != nil ? 1.06 : 1)
                    .position(hubCenter)
                    .animation(.easeOut(duration: 0.14), value: menu.centerCatScale)
                    .allowsHitTesting(false)
                }

            }
            .compositingGroup()
            .environment(\.colorScheme, .dark)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    pointerForCatEyes = location
                    let dx = location.x - cx
                    let dy = location.y - cy
                    let dist = sqrt(dx * dx + dy * dy)
                    if dist < drawInnerRadius {
                        hoveredSectorIndex = nil
                        isCenterHovered = true
                    } else if dist <= drawRadius {
                        isCenterHovered = false
                        let angle = atan2(dy, dx)
                        hoveredSectorIndex = absoluteSectorIndex(from: angle, radiusAtPoint: dist)
                    } else {
                        hoveredSectorIndex = nil
                        isCenterHovered = false
                    }
                case .ended:
                    pointerForCatEyes = nil
                    hoveredSectorIndex = nil
                    isCenterHovered = false
                }
            }
            .onChange(of: hoveredSectorIndex) { newIndex in
                guard let newIndex else { return }
                lastPawSectorIndex = newIndex
                if hapticFeedbackEnabled {
                    NSHapticFeedbackManager.defaultPerformer.perform(
                        .levelChange,
                        performanceTime: .default
                    )
                }
            }
            .animation(DS.Motion.sectorHighlight, value: hoveredSectorIndex)
            .animation(.easeInOut(duration: 0.15), value: isCenterHovered)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let moved = hypot(value.translation.width, value.translation.height)

                        if isRotatingWheel {
                            applyWheelRotation(fingerLocation: value.location, cx: cx, cy: cy)
                            return
                        }

                        if draggedItemId == nil && moved > 6 {
                            let distStart = hypot(value.startLocation.x - cx, value.startLocation.y - cy)
                            if isOptionKeyDown(),
                               distStart >= drawInnerRadius,
                               distStart <= drawRadius {
                                if !isRotatingWheel {
                                    isRotatingWheel = true
                                    lastRotationSnapForHaptic = nil
                                    rotationAnchorMenuDegrees = menu.rotationDegrees
                                    rotationAnchorPointerAngle = atan2(
                                        value.startLocation.y - cy,
                                        value.startLocation.x - cx
                                    )
                                }
                                return
                            }
                            let draggable = reorderableItems
                            guard !draggable.isEmpty else { return }
                            let dist = hypot(value.startLocation.x - cx, value.startLocation.y - cy)
                            guard dist >= drawInnerRadius && dist <= drawRadius else { return }
                            let startA = atan2(value.startLocation.y - cy, value.startLocation.x - cx)
                            guard let idx = absoluteSectorIndex(from: startA, radiusAtPoint: dist), idx < draggable.count else { return }
                            draggedItemId = draggable[idx].id
                            dragStartSectorIndex = idx
                            lastReorderHapticSlot = idx
                            var cAngle = (
                                startAngle(for: idx)
                                + endAngle(for: idx)
                            ) / 2
                            if cAngle > .pi { cAngle -= 2 * .pi }
                            if cAngle < -.pi { cAngle += 2 * .pi }
                            dragStartAngle = cAngle
                        }
                        if draggedItemId != nil {
                            dragAngle = atan2(value.location.y - cy, value.location.x - cx)
                            let slot = reorderDropIndex(for: dragAngle)
                            if lastReorderHapticSlot != slot {
                                lastReorderHapticSlot = slot
                                if hapticFeedbackEnabled {
                                    NSHapticFeedbackManager.defaultPerformer.perform(
                                        .alignment,
                                        performanceTime: .default
                                    )
                                }
                            }
                        }
                    }
                    .onEnded { value in
                        if isRotatingWheel {
                            isRotatingWheel = false
                            lastRotationSnapForHaptic = nil
                            return
                        }
                        lastReorderHapticSlot = nil
                        let moved = hypot(value.translation.width, value.translation.height)
                        if draggedItemId == nil && moved <= 6 {
                            let tapAngle = atan2(value.location.y - cy, value.location.x - cx)
                            let dist = hypot(value.location.x - cx, value.location.y - cy)
                            if dist < drawInnerRadius {
                                if let onAdd = onAddItem {
                                    onAdd()
                                } else if !menu.items.isEmpty || menu.isDynamicMenu {
                                    selectedItemId = nil
                                }
                            } else {
                                if menu.isAppCommandsMenu {
                                    if dist <= drawRadius + 10 * scale,
                                       let idx = absoluteSectorIndex(from: tapAngle, radiusAtPoint: dist),
                                       idx < previewItems.count {
                                        let tappedId = previewItems[idx].id
                                        selectedItemId = selectedItemId == tappedId ? nil : tappedId
                                    } else {
                                        selectedItemId = nil
                                    }
                                    return
                                }
                                if menu.isDynamicMenu {
                                    selectedItemId = nil
                                    return
                                }
                                guard !menu.items.isEmpty else { return }
                                if dist >= drawInnerRadius && dist <= drawRadius + 10 * scale {
                                    if let idx = absoluteSectorIndex(from: tapAngle, radiusAtPoint: dist), idx < realItems.count {
                                        let tappedId = realItems[idx].id
                                        selectedItemId = selectedItemId == tappedId ? nil : tappedId
                                    }
                                } else {
                                    selectedItemId = nil
                                }
                            }
                        } else if let id = draggedItemId {
                            let sorted = previewItems
                            let target = dropIndex
                            if menu.isAppCommandsMenu,
                               let fromPos = menu.appCommandsDefaultEntries.firstIndex(where: { $0.id == id }),
                               fromPos != target,
                               target < menu.appCommandsDefaultEntries.count {
                                menu.appCommandsDefaultEntries.swapAt(fromPos, target)
                            } else if let fromPos = sorted.firstIndex(where: { $0.id == id }),
                               fromPos != target,
                               target < sorted.count {
                                let draggedSector = sorted[fromPos].sectorIndex
                                let targetSector = sorted[target].sectorIndex
                                if let i = menu.items.firstIndex(where: { $0.id == id }),
                                   let j = menu.items.firstIndex(where: { $0.sectorIndex == targetSector }) {
                                    menu.items[i].sectorIndex = targetSector
                                    menu.items[j].sectorIndex = draggedSector
                                }
                            }
                        }
                        draggedItemId = nil
                    }
            )
            .contextMenu {
                if menu.isAppCommandsMenu, menu.appCommandsDefaultEntries.count > 1,
                   let idx = hoveredSectorIndex, idx < itemsToShow.count {
                    Button(role: .destructive) {
                        removeAppSetEntry(id: itemsToShow[idx].id)
                    } label: {
                        Label(localizer.text(.subMenuRemove), systemImage: "minus.circle")
                    }
                }
                if !menu.isDynamicMenu,
                   let idx = hoveredSectorIndex, idx < itemsToShow.count, !isGhost {
                    Button {
                        duplicatePreviewItem(id: itemsToShow[idx].id)
                    } label: {
                        Label(localizer.text(.duplicateItem), systemImage: "plus.square.on.square")
                    }
                    Button {
                        copyPreviewItem(id: itemsToShow[idx].id)
                    } label: {
                        Label(localizer.text(.copyMenuItem), systemImage: "doc.on.doc")
                    }
                }
                if canPasteMenuItem {
                    Button {
                        pasteMenuItemFromClipboard()
                    } label: {
                        Label(localizer.text(.pasteMenuItem), systemImage: "doc.on.clipboard")
                    }
                }
                if !menu.isDynamicMenu,
                   let idx = hoveredSectorIndex, idx < itemsToShow.count, !isGhost {
                    Divider()
                    Button(role: .destructive) {
                        deletePreviewItem(id: itemsToShow[idx].id)
                    } label: {
                        Label(localizer.text(.deleteItem), systemImage: "trash")
                    }
                }
            }
        }
        .frame(minHeight: 120)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Стекло секторов

extension MenuPreviewView {
    private var showsGhost: Bool {
        switch menu.kind {
        case .runningApps: return liveRunningAppsItems.isEmpty
        case .appCommands: return false
        case .standard: return menu.items.isEmpty
        }
    }

    /// Пустой сектор залит цветом темы так же, как соседи; пустоту видно по иконке и обводке.
    private func fillFactor(for item: PieMenuItem) -> Double {
        showsGhost ? 0.25 : 1
    }

    /// Угол сектора с учётом перетаскивания: перетаскиваемый едет за курсором.
    private func drawAngles(index: Int, itemId: UUID) -> (start: Double, end: Double) {
        guard draggedItemId == itemId else { return (startAngle(for: index), endAngle(for: index)) }
        return (dragAngle - sectorAngle / 2, dragAngle + sectorAngle / 2)
    }

    /// Стекло всех секторов — в одном контейнере, как в самом меню. Поодиночке адаптивное стекло
    /// подстраивается каждое под свой фон и «перещёлкивается» вразнобой: секторы выглядят то плотнее,
    /// то прозрачнее.
    @ViewBuilder
    private func glassLayer(
        items: [PieMenuItem],
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        cornerRadius: CGFloat
    ) -> some View {
        let fills = ZStack {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let angles = drawAngles(index: index, itemId: item.id)
                PieSectorFillView(
                    startAngle: angles.start,
                    endAngle: angles.end,
                    innerRadius: innerRadius,
                    outerRadius: outerRadius,
                    cornerRadius: cornerRadius,
                    tintColor: Color(hex: item.color) ?? .accentColor,
                    fillOpacityFactor: fillFactor(for: item),
                    glassSettings: menu.liquidGlass,
                    interactiveGlass: false
                )
            }
        }
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 0) { fills }
        } else {
            fills
        }
    }
}

// MARK: - Кнопки над превью

extension MenuPreviewView {
    /// Что можно делать в превью — одним списком по кнопке «i».
    private var hintsButton: some View {
        PreviewToolbarButton(
            icon: "info.circle",
            isActive: showsHints,
            help: localizer.text(.previewHintsHelp)
        ) {
            showsHints.toggle()
        }
        .popover(isPresented: $showsHints, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                ForEach(previewHints, id: \.text) { hint in
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
                        Image(systemName: hint.icon)
                            .font(DS.Typography.label)
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        Text(hint.text)
                            .font(DS.Typography.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(DS.Spacing.m + 2)
            .frame(width: 320, alignment: .leading)
        }
    }

    private var previewHints: [(icon: String, text: String)] {
        var hints: [(icon: String, text: String)] = []
        if menu.isRunningAppsMenu {
            hints.append(("app.badge", localizer.text(.runningAppsEditorHint)))
        } else {
            if menu.isAppCommandsMenu, !isAppSet {
                hints.append(("command", localizer.text(.appCommandsPreviewHint)))
            }
            hints.append(("hand.tap", localizer.text(.tapSectorToEdit)))
            hints.append(("arrow.left.arrow.right", localizer.text(.dragToReorder)))
        }
        hints.append(("option", localizer.text(.optionDragToRotate)))
        if onAddItem != nil {
            hints.append(("pawprint", localizer.text(.tapCatToAddHint)))
        }
        return hints
    }
}

// MARK: - Копирование и вставка пунктов

extension MenuPreviewView {
    private var standardMenuShowsGhostPreview: Bool {
        !menu.isDynamicMenu && menu.items.isEmpty
    }

    private var canPasteMenuItem: Bool {
        guard !menu.isDynamicMenu, PieMenuItemPasteboard.read() != nil else { return false }
        if !standardMenuShowsGhostPreview,
           let idx = hoveredSectorIndex,
           idx < realItems.count {
            return true
        }
        return menu.items.isEmpty
    }

    private func copyPreviewItem(id: UUID) {
        guard let item = menu.items.first(where: { $0.id == id }) else { return }
        PieMenuItemPasteboard.copy(item)
    }

    private func pasteMenuItemFromClipboard() {
        guard !menu.isDynamicMenu, let template = PieMenuItemPasteboard.read() else { return }
        if !standardMenuShowsGhostPreview,
           let idx = hoveredSectorIndex,
           idx < realItems.count {
            let targetId = realItems[idx].id
            guard let i = menu.items.firstIndex(where: { $0.id == targetId }) else { return }
            let sector = menu.items[i].sectorIndex
            let newItem = PieMenuItemPasteboard.itemForPasting(template: template, sectorIndex: sector)
            withoutAnimation {
                menu.items[i] = newItem
            }
            if selectedItemId == targetId {
                selectedItemId = newItem.id
            }
            return
        }
        guard menu.items.isEmpty else { return }
        let newItem = PieMenuItemPasteboard.itemForPasting(template: template, sectorIndex: 0)
        withoutAnimation {
            menu.items.append(newItem)
        }
    }

    /// Подпись сектора в превью: у команды — её название, у пункта — как в кольце.
    private func previewHoverLabel(for item: PieMenuItem, at index: Int) -> PieHoverLabelText? {
        if menu.isAppCommandsMenu {
            guard index < menu.appCommandsDefaultEntries.count else { return nil }
            let entry = menu.appCommandsDefaultEntries[index]
            let appName = AppSubMenuEditorView.appName(for: previewAppBundleId)
            return PieHoverLabelText(
                title: entry.displayTitle(appName: appName, language: localizer.language),
                detail: entry.shortcut?.displayString
            )
        }
        return item.hoverLabel(language: localizer.language)
    }

    /// Копия сектора — следом за оригиналом, на первом свободном месте кольца.
    private func duplicatePreviewItem(id: UUID) {
        guard let original = menu.items.first(where: { $0.id == id }) else { return }
        let copy = PieMenuItemPasteboard.itemForPasting(template: original, sectorIndex: menu.nextFreeSectorIndex)
        withoutAnimation {
            menu.items.append(copy)
            menu.snapRotationToAestheticAnchor()
        }
        selectedItemId = copy.id
    }

    private func removeAppSetEntry(id: UUID) {
        guard menu.appCommandsDefaultEntries.count > 1 else { return }
        withoutAnimation {
            menu.appCommandsDefaultEntries.removeAll { $0.id == id }
            menu.snapRotationToAestheticAnchor()
        }
        if selectedItemId == id { selectedItemId = nil }
    }

    private func deletePreviewItem(id: UUID) {
        guard menu.items.count > PieMenuItem.minItemCount else { return }
        withoutAnimation {
            menu.items.removeAll { $0.id == id }
            menu.snapRotationToAestheticAnchor()
        }
        if selectedItemId == id { selectedItemId = nil }
    }
}

private struct MenuPreviewPreview: View {
    @State private var menu = PieConfiguration.defaultConfig.menus[0]
    @State private var selectedItemId: UUID?
    @State private var isAppearancePanelVisible = false
    var body: some View {
        MenuPreviewView(
            menu: $menu,
            selectedItemId: $selectedItemId,
            hapticFeedbackEnabled: true,
            isAppearancePanelVisible: isAppearancePanelVisible,
            onAddItem: {}
        )
            .frame(width: 500, height: 500)
            .background(DS.Colors.canvasTop)
            .preferredColorScheme(.dark)
            .environmentObject(LocalizationStore(language: .russian))
    }
}

#Preview("MenuPreview") {
    MenuPreviewPreview()
}
