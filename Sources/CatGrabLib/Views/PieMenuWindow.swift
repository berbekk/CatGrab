@preconcurrency import AppKit
import SwiftUI
import QuartzCore

class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Корень окна кольца. Меню — `nil`, пока нечего показывать. Дерево живёт между показами: одно и то же
/// меню при следующем открытии лишь обновляется, а не собирается заново — это в несколько раз быстрее.
private struct PieMenuRootView: View {
    var menu: PieMenuView?

    var body: some View {
        if let menu {
            menu
        }
    }
}

@MainActor
final class PieMenuWindowController {
    /// Одно окно на всё время работы: полноэкранное окно с буфером и SwiftUI-хостом создавать заново
    /// при каждом вызове — это десятки миллисекунд ещё до первого кадра. Здесь оно создаётся один раз,
    /// прогревается при запуске и дальше только показывается и прячется.
    private var window: OverlayPanel?
    private var hostingView: NSHostingView<PieMenuRootView>?
    /// Появление и взгляд кота — общие для всех показов: дерево SwiftUI не пересоздаётся.
    private let presentation = PieMenuPresentation()
    private let highlightState = PieMenuHighlightState()
    private var localMonitor: Any?
    private var screenParamsObserver: NSObjectProtocol?
    private var modifierChordReleaseMonitors: [Any] = []
    private var modifierChordReleaseWorkItem: DispatchWorkItem?
    private var chordNavigationHotkey: HotkeyConfig?
    /// Пока `true`, игнорируем переключение по аккорду (удержание после открытия даёт только key repeat).
    private var chordNavigationIgnoreUntilMainKeyUp: Bool = false
    private var lastChordAdvanceUptime: TimeInterval = 0
    /// Команды приложения, если показано меню «Команды приложения»: по одной на каждый пункт `displayedItems`.
    private var displayedCommands: [PieSubAction]?
    private var displayedItems: [PieMenuItem] = []
    private var displayedShortcutLabels: [String?] = []
    /// Секторы, которые сейчас нельзя выбрать: недоступные команды и приложения, которых нет на этом Mac.
    private var displayedDisabledIndices: Set<Int> = []
    private var displayedRotationRadians: Double = 0
    private var displayedHapticFeedback = true
    private(set) var displayedMenuId: UUID?
    var onItemSelected: ((PieMenuItem) -> Void)?
    var onCommandSelected: ((PieSubAction) -> Void)?
    private(set) var showMouseLocation: CGPoint?
    /// Поддержка быстрых выборов: `0...9`, затем `QWERTYUIOP`, `ASDFGHJKL`, `ZXCVBNM`.
    private static let quickSelectIndexByKeyCode: [UInt16: Int] = [
        // Верхний ряд
        29: 0, 18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9,
        // Numpad
        82: 0, 83: 1, 84: 2, 85: 3, 86: 4, 87: 5, 88: 6, 89: 7, 91: 8, 92: 9,
        // QWERTY top row
        12: 10, 13: 11, 14: 12, 15: 13, 17: 14, 16: 15, 32: 16, 34: 17, 31: 18, 35: 19,
        // ASDFGHJKL
        0: 20, 1: 21, 2: 22, 3: 23, 5: 24, 4: 25, 38: 26, 40: 27, 37: 28,
        // ZXCVBNM
        6: 29, 7: 30, 8: 31, 9: 32, 11: 33, 45: 34, 46: 35
    ]

    /// Стрелки: сектор в направлении стрелки (в экранных координатах, ось Y вниз).
    private static let arrowDirections: [UInt16: Double] = [
        126: -.pi / 2, // ↑
        124: 0, // →
        125: .pi / 2, // ↓
        123: .pi // ←
    ]

    deinit {
        // Вытесняем уборку на MainActor, так как NSEvent‑мониторы и AppKit‑окна MainActor‑изолированы.
        // Захватываем всё по значению заранее, чтобы не трогать `self` после освобождения.
        let capturedLocal = localMonitor
        let capturedScreen = screenParamsObserver
        let capturedWindow = window
        let capturedReleaseMonitors = modifierChordReleaseMonitors
        DispatchQueue.main.async {
            if let l = capturedLocal { NSEvent.removeMonitor(l) }
            if let o = capturedScreen { NotificationCenter.default.removeObserver(o) }
            for m in capturedReleaseMonitors { NSEvent.removeMonitor(m) }
            capturedWindow?.orderOut(nil)
        }
    }

    var isVisible: Bool {
        displayedMenuId != nil && (window?.isVisible ?? false)
    }

    /// Что выполнить при отпускании хоткея: выделенный пункт или, в меню команд, выделенная команда.
    var currentSelection: PieMenuSelection? {
        guard displayedMenuId != nil,
              let idx = highlightState.highlightedIndex,
              idx >= 0, idx < displayedItems.count,
              !displayedDisabledIndices.contains(idx) else { return nil }
        if let displayedCommands {
            guard idx < displayedCommands.count, displayedCommands[idx].isEnabled else { return nil }
            return .subAction(displayedCommands[idx])
        }
        return .item(displayedItems[idx])
    }

    /// Пока удерживается хоткей после открытия меню — не принимаем шаг из Carbon/HID (повтор keyDown).
    var isChordNavigationAdvanceSuppressed: Bool {
        chordNavigationHotkey != nil && chordNavigationIgnoreUntilMainKeyUp
    }

    func clearChordNavigationInitialHoldSuppression() {
        guard chordNavigationHotkey != nil else { return }
        chordNavigationIgnoreUntilMainKeyUp = false
    }

    func advanceRunningAppsSelection() {
        guard !displayedItems.isEmpty else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastChordAdvanceUptime < Timings.chordAdvanceDebounce { return }
        lastChordAdvanceUptime = now
        withAnimation(DS.Motion.sectorHighlight) {
            highlightState.advanceSelection(sectorCount: displayedItems.count, hapticFeedbackEnabled: displayedHapticFeedback)
        }
    }

    /// Режим «по клику»: после открытия меню — закрытие при отпускании любого модификатора хоткея (если в сочетании есть модификаторы).
    func scheduleClickModeModifierChordReleaseDismissal(hotkey: HotkeyConfig, onReleased: @escaping () -> Void) {
        cancelModifierChordReleaseArming()
        guard hotkey.carbonModifiers != 0 else { return }
        let required = hotkey.nsDeviceIndependentModifierFlags
        let work = DispatchWorkItem { [weak self] in
            self?.modifierChordReleaseWorkItem = nil
            guard let self, self.isVisible else { return }
            self.installModifierChordReleaseMonitors(required: required, onReleased: onReleased)
        }
        modifierChordReleaseWorkItem = work
        // Следующий цикл run loop: окно уже ключевое, а события отпускания не теряются из‑за задержки.
        DispatchQueue.main.async(execute: work)
    }

    private func installModifierChordReleaseMonitors(required: NSEvent.ModifierFlags, onReleased: @escaping () -> Void) {
        removeModifierChordReleaseMonitors()
        let current = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if !current.contains(required) {
            onReleased()
            return
        }
        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self else { return }
            let current = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if !current.contains(required) {
                self.removeModifierChordReleaseMonitors()
                onReleased()
            }
        }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { event in
            handler(event)
            return event
        }) {
            modifierChordReleaseMonitors.append(m)
        }
    }

    private func removeModifierChordReleaseMonitors() {
        for m in modifierChordReleaseMonitors {
            NSEvent.removeMonitor(m)
        }
        modifierChordReleaseMonitors.removeAll()
    }

    private func cancelModifierChordReleaseArming() {
        modifierChordReleaseWorkItem?.cancel()
        modifierChordReleaseWorkItem = nil
    }

    private func displayedItem(forQuickSelectIndex index: Int) -> PieMenuItem? {
        guard index >= 0, index < displayedItems.count else { return nil }
        return displayedItems[index]
    }

    /// Индекс пункта, чья эффективная подпись-шорткат совпадает с нажатым символом.
    private func displayedItemIndex(forPressedKey key: String?) -> Int? {
        guard let key, !key.isEmpty else { return nil }
        return PieMenu.itemIndex(forPressedKey: key, resolvedLabels: displayedShortcutLabels)
    }

    // MARK: - Окно

    /// Окно и SwiftUI-хост — один раз. Окно занимает рабочую область экрана, где курсор: кадр
    /// переставляется при каждом показе (`show`), потому что экран может быть другим.
    private func ensureWindow() -> (OverlayPanel, NSHostingView<PieMenuRootView>) {
        if let window, let hostingView { return (window, hostingView) }
        let window = OverlayPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 800, height: 600)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.hasShadow = false
        window.animationBehavior = .none
        window.hidesOnDeactivate = false
        window.isFloatingPanel = true
        window.isReleasedWhenClosed = false
        // Пункты меню должны всегда выглядеть одинаково, независимо от темы macOS: фиксируем тёмный appearance,
        // чтобы Liquid Glass / .ultraThinMaterial и системные тонировки не переключались вслед за системой.
        window.appearance = NSAppearance(named: .darkAqua)
        window.collectionBehavior = [
            .moveToActiveSpace,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]
        let hostingView = NSHostingView(rootView: PieMenuRootView(menu: nil))
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView
        self.window = window
        self.hostingView = hostingView
        return (window, hostingView)
    }

    /// Прогрев при запуске: окно, хост и кольцо с первым меню собираются заранее и показываются на один
    /// кадр невидимыми (прозрачное окно, без активации), чтобы шрифты, стекло и слои уже были готовы.
    /// Первое настоящее открытие тогда стоит столько же, сколько любое следующее.
    func prewarm(menu: PieMenu) {
        guard displayedMenuId == nil, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let items = menu.themed(menu.items.sorted { $0.sectorIndex < $1.sectorIndex })
        guard !items.isEmpty else { return }
        let (window, hostingView) = ensureWindow()
        window.setFrame(screen.visibleFrame, display: false)
        let bounds = screen.visibleFrame.size
        presentation.appeared = true
        hostingView.rootView = PieMenuRootView(
            menu: makeMenuView(
                menu: menu,
                items: items,
                center: CGPoint(x: bounds.width / 2, y: bounds.height / 2),
                appCommands: nil,
                options: ViewOptions(disabledIndices: [], hapticFeedbackEnabled: false, language: .english, interactive: false)
            )
        )
        hostingView.layoutSubtreeIfNeeded()
        window.alphaValue = 0
        window.orderFrontRegardless()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.displayedMenuId == nil, let window = self.window else { return }
            window.orderOut(nil)
            window.alphaValue = 1
        }
    }

    /// Команды приложения для меню «Команды приложения» и чьи они.
    struct AppCommands {
        let bundleIdentifier: String
        let actions: [PieSubAction]
        /// Команды набора, из которых получены `actions`: у них цвета и клавиши секторов.
        let entries: [AppSubMenuEntry]
    }

    func show(
        menu: PieMenu,
        itemsOverride: [PieMenuItem]? = nil,
        navigationHotkeyForChordRepeat: HotkeyConfig? = nil,
        appCommands: AppCommands? = nil
    ) {
        let showStart = CACurrentMediaTime()
        let items = menu.themed(appCommands.map {
            AppCommandsMenuItems.build(actions: $0.actions, entries: $0.entries, bundleIdentifier: $0.bundleIdentifier)
        } ?? itemsOverride ?? menu.items)
        guard !items.isEmpty else { return }

        // Защита от повторного `show()` без `hide()`: иначе вешаются лишние мониторы и «висит» прежнее окно.
        if displayedMenuId != nil {
            hide()
        }

        cancelModifierChordReleaseArming()
        removeModifierChordReleaseMonitors()
        chordNavigationHotkey = nil
        chordNavigationIgnoreUntilMainKeyUp = false
        lastChordAdvanceUptime = 0

        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
                ?? NSScreen.main
                ?? NSScreen.screens.first else { return }
        // `visibleFrame` исключает меню-бар и Dock — меню не заползёт под системные элементы.
        let frame = screen.visibleFrame
        let (window, hostingView) = ensureWindow()
        if window.frame != frame {
            window.setFrame(frame, display: false)
        }

        let sortedItems = items.sorted { $0.sectorIndex < $1.sectorIndex }
        let configuration = ConfigManager.shared.configuration
        let disabledIndices = Self.disabledIndices(items: sortedItems, commands: appCommands?.actions)
        displayedItems = sortedItems
        displayedShortcutLabels = PieMenu.resolvedShortcutLabels(for: sortedItems)
        displayedDisabledIndices = disabledIndices
        displayedRotationRadians = menu.rotationDegrees * .pi / 180
        displayedHapticFeedback = configuration.hapticFeedbackEnabled
        withoutAnimation { highlightState.highlightedIndex = menu.isRunningAppsMenu ? 0 : nil }
        displayedMenuId = menu.id
        // `build` уже расставил команды по порядку, `sortedItems` совпадает с ними поэлементно.
        displayedCommands = appCommands?.actions

        // Координаты SwiftUI: начало в верхнем левом углу окна.
        let proposedCenter = CGPoint(
            x: mouseLocation.x - frame.origin.x,
            y: frame.height - (mouseLocation.y - frame.origin.y)
        )
        let menuCenter = PieMenuPlacement.clampedCenter(
            proposed: proposedCenter,
            radius: CGFloat(menu.effectiveMenuRadius),
            bounds: frame.size
        )
        if PieMenuPlacement.needsCursorWarp(proposed: proposedCenter, center: menuCenter) {
            PieLog.window.debug("show: ring clamped to screen edge, cursor moved to its center")
            Self.warpCursor(toWindowPoint: menuCenter, windowFrame: frame)
        }

        // Первый кадр — невидимый: появление стартует со следующего прохода run loop, иначе SwiftUI
        // анимировал бы от прошлого показа (уже видимого) к видимому, то есть никак.
        // Без анимаций: новый центр, другие пункты и сброс выделения должны встать на место сразу.
        withoutAnimation {
            presentation.pointer = menuCenter
            presentation.appeared = menu.isRunningAppsMenu
            hostingView.rootView = PieMenuRootView(
                menu: makeMenuView(
                    menu: menu,
                    items: sortedItems,
                    center: menuCenter,
                    appCommands: appCommands,
                    options: ViewOptions(
                        disabledIndices: disabledIndices,
                        hapticFeedbackEnabled: configuration.hapticFeedbackEnabled,
                        language: configuration.language,
                        interactive: true
                    )
                )
            )
        }

        chordNavigationHotkey = navigationHotkeyForChordRepeat
        chordNavigationIgnoreUntilMainKeyUp = navigationHotkeyForChordRepeat != nil

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyEvent(event)
        }

        // Отключение монитора / смена разрешения во время показа оставляют оверлей в призрачных координатах.
        screenParamsObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.hide() }
        }

        window.alphaValue = 1
        window.orderFrontRegardless()
        window.makeKey()
        showMouseLocation = NSEvent.mouseLocation
        if !presentation.appeared {
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            DispatchQueue.main.async { [presentation] in
                withAnimation(reduceMotion ? nil : DS.Motion.pieEntrance) {
                    presentation.appeared = true
                }
            }
        }
        PieLog.window.debug("show: \(Int((CACurrentMediaTime() - showStart) * 1000))ms, \(sortedItems.count) sectors")
    }

    /// Что у кольца кроме самого меню: недоступные секторы, отдача, язык подписей и принимает ли оно
    /// выбор (прогрев при запуске — не принимает).
    private struct ViewOptions {
        let disabledIndices: Set<Int>
        let hapticFeedbackEnabled: Bool
        let language: AppLanguage
        let interactive: Bool
    }

    private func makeMenuView(
        menu: PieMenu,
        items: [PieMenuItem],
        center: CGPoint,
        appCommands: AppCommands?,
        options: ViewOptions
    ) -> PieMenuView {
        let interactive = options.interactive
        return PieMenuView(
            items: items,
            radius: menu.effectiveMenuRadius,
            innerRadius: menu.effectiveInnerRadius,
            iconDistance: menu.iconDistance,
            iconSize: menu.fittedIconSize(sectorCount: items.count),
            rotationDegrees: menu.rotationDegrees,
            liquidGlass: menu.liquidGlass,
            menuCenter: center,
            pawDecorationEnabled: menu.pawDecorationEnabled,
            pawSizeScale: menu.pawSizeScale,
            pawRadialInset: menu.pawRadialInset,
            centerCatScale: menu.centerCatScale,
            centerAppIconScale: menu.centerAppIconScale,
            shortcutDigitSizeScale: menu.shortcutDigitSizeScale,
            shortcutDigitInsetLeftScale: menu.shortcutDigitInsetLeftScale,
            shortcutDigitInsetRightScale: menu.shortcutDigitInsetRightScale,
            shortcutDigitOpacity: menu.shortcutDigitOpacity,
            shortcutDigitColorHex: menu.shortcutDigitColorHex,
            catColorHex: menu.catColorHex,
            pawColorHex: menu.pawColorHex,
            innerCircleHighlightsFirstSector: menu.isRunningAppsMenu,
            commands: appCommands?.actions,
            commandsAppBundleId: appCommands?.bundleIdentifier,
            hoverLabels: menu.showsHoverLabel ? items.map { $0.hoverLabel(language: options.language) } : nil,
            disabledIndices: options.disabledIndices,
            highlightState: highlightState,
            presentation: presentation,
            hapticFeedbackEnabled: options.hapticFeedbackEnabled,
            onItemSelected: interactive ? { [weak self] item in self?.onItemSelected?(item) } : nil,
            onCommandSelected: interactive ? { [weak self] action in self?.onCommandSelected?(action) } : nil,
            onDismiss: interactive ? { [weak self] in self?.hide() } : nil
        )
    }

    /// Приложения, которых нет на этом Mac, и недоступные команды: сектор виден приглушённым на своём
    /// месте, но выбрать его нельзя — иначе выбор молча ничего не делал бы.
    static func disabledIndices(items: [PieMenuItem], commands: [PieSubAction]?) -> Set<Int> {
        if let commands {
            return Set(commands.indices.filter { !commands[$0].isEnabled })
        }
        return Set(items.indices.filter { index in
            guard case .launchApp(let bundleId) = items[index].action, !bundleId.isEmpty else { return false }
            return !AppIconResolver.shared.isInstalled(bundleIdentifier: bundleId)
        })
    }

    /// Курсор — в центр кольца. Точка из координат SwiftUI окна (ось Y вниз) в координаты
    /// Core Graphics (начало — верхний левый угол главного экрана, ось Y вниз).
    private static func warpCursor(toWindowPoint point: CGPoint, windowFrame: NSRect) {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return }
        let screenX = windowFrame.origin.x + point.x
        let screenY = windowFrame.origin.y + (windowFrame.height - point.y)
        CGWarpMouseCursorPosition(CGPoint(x: screenX, y: primaryHeight - screenY))
    }

    // MARK: - Клавиатура

    /// Клавиши при открытом меню: Esc, быстрый выбор, повтор хоткея, стрелки и Tab по секторам,
    /// Return — выполнить выделенное.
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        switch event.type {
        case .keyUp:
            if let chord = chordNavigationHotkey,
               event.keyCode == UInt16(chord.keyCode) {
                chordNavigationIgnoreUntilMainKeyUp = false
            }
            return event
        case .keyDown:
            if event.keyCode == UInt16(KeyCodes.escape) {
                hide()
                return nil
            }
            if let customIndex = displayedItemIndex(forPressedKey: event.charactersIgnoringModifiers)
                ?? displayedItemIndex(forPressedKey: event.characters),
               displayedItem(forQuickSelectIndex: customIndex) != nil {
                selectDisplayed(index: customIndex)
                return nil
            }
            if let quickSelectIndex = Self.quickSelectIndexByKeyCode[event.keyCode],
               quickSelectIndex < displayedShortcutLabels.count,
               displayedShortcutLabels[quickSelectIndex] != nil,
               displayedItem(forQuickSelectIndex: quickSelectIndex) != nil {
                selectDisplayed(index: quickSelectIndex)
                return nil
            }
            if let chord = chordNavigationHotkey,
               chord.matchesKeyDownForChordRepeat(event),
               !chordNavigationIgnoreUntilMainKeyUp {
                advanceRunningAppsSelection()
                return nil
            }
            if handleNavigationKey(event) {
                return nil
            }
            return event
        default:
            return event
        }
    }

    /// Стрелки — сектор в их направлении, Tab/⇧Tab — по кругу, Return или пробел — выполнить.
    /// Пробел и Return считаются только без модификаторов: с зажатыми ⌃⌥ пробел — это сам хоткей.
    private func handleNavigationKey(_ event: NSEvent) -> Bool {
        guard !displayedItems.isEmpty else { return false }
        let hs = highlightState
        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.function, .numericPad])
        if let direction = Self.arrowDirections[event.keyCode] {
            let index = PieSectorLayout.sectorIndex(
                closestToDirection: direction,
                sectorCount: displayedItems.count,
                rotationRadians: displayedRotationRadians
            )
            withAnimation(DS.Motion.sectorHighlight) {
                hs.select(index, hapticFeedbackEnabled: displayedHapticFeedback)
            }
            PieLog.window.debug("keyboard: arrow → sector \(index ?? -1)")
            return true
        }
        if event.keyCode == UInt16(KeyCodes.tab), modifiers.subtracting(.shift).isEmpty {
            let offset = modifiers.contains(.shift) ? -1 : 1
            withAnimation(DS.Motion.sectorHighlight) {
                hs.select(
                    PieSectorLayout.cycledIndex(from: hs.highlightedIndex, by: offset, sectorCount: displayedItems.count),
                    hapticFeedbackEnabled: displayedHapticFeedback
                )
            }
            return true
        }
        let confirmKeys: Set<UInt16> = [UInt16(KeyCodes.returnKey), 76, UInt16(KeyCodes.space)]
        if confirmKeys.contains(event.keyCode), modifiers.isEmpty {
            guard let index = hs.highlightedIndex else { return true }
            selectDisplayed(index: index)
            return true
        }
        return false
    }

    /// Быстрый выбор: пункт обычного меню или команда в меню команд. Недоступный сектор ничего не делает.
    private func selectDisplayed(index: Int) {
        guard !displayedDisabledIndices.contains(index) else { return }
        if let displayedCommands {
            guard index < displayedCommands.count, displayedCommands[index].isEnabled else { return }
            onCommandSelected?(displayedCommands[index])
        } else if let item = displayedItem(forQuickSelectIndex: index) {
            onItemSelected?(item)
        }
    }

    func hide() {
        cancelModifierChordReleaseArming()
        removeModifierChordReleaseMonitors()
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let observer = screenParamsObserver {
            NotificationCenter.default.removeObserver(observer)
            screenParamsObserver = nil
        }
        // Без смены картинки: иначе перед исчезновением окна успевал отрисоваться лишний кадр,
        // и меню дёргалось при отпускании. Кольцо остаётся в окне и живёт до следующего показа.
        displayedCommands = nil
        withoutAnimation { highlightState.reset() }
        displayedItems = []
        displayedShortcutLabels = []
        displayedDisabledIndices = []
        displayedMenuId = nil
        chordNavigationHotkey = nil
        chordNavigationIgnoreUntilMainKeyUp = false
        lastChordAdvanceUptime = 0
        showMouseLocation = nil
        window?.orderOut(nil)
        PieLog.window.debug("hide")
    }
}
