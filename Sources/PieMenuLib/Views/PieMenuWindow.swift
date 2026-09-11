@preconcurrency import AppKit
import SwiftUI

class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PieMenuWindowController {
    private var window: NSWindow?
    private var localMonitor: Any?
    private var screenParamsObserver: NSObjectProtocol?
    private var modifierChordReleaseMonitors: [Any] = []
    private var modifierChordReleaseWorkItem: DispatchWorkItem?
    private var chordNavigationHotkey: HotkeyConfig?
    /// Пока `true`, игнорируем переключение по аккорду (удержание после открытия даёт только key repeat).
    private var chordNavigationIgnoreUntilMainKeyUp: Bool = false
    private var lastChordAdvanceUptime: TimeInterval = 0
    private var highlightState: PieMenuHighlightState?
    private var displayedItems: [PieMenuItem] = []
    private var displayedShortcutLabels: [String?] = []
    private(set) var displayedMenuId: UUID?
    var onItemSelected: ((PieMenuItem) -> Void)?
    var onHoverChanged: ((PieMenuItem?) -> Void)?
    var onHide: (() -> Void)?
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
        window?.isVisible ?? false
    }

    var currentHoveredItem: PieMenuItem? {
        guard let idx = highlightState?.highlightedIndex,
              idx >= 0, idx < displayedItems.count else { return nil }
        return displayedItems[idx]
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
        guard let hs = highlightState, !displayedItems.isEmpty else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastChordAdvanceUptime < Timings.chordAdvanceDebounce { return }
        lastChordAdvanceUptime = now
        hs.advanceSelection(
            sectorCount: displayedItems.count,
            hapticFeedbackEnabled: ConfigManager.shared.configuration.hapticFeedbackEnabled
        )
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

    /// Центр кругового меню в координатах SwiftUI (верхний левый угол), чтобы круг радиуса `radius` не выходил за границы окна.
    private static func clampedMenuCenter(
        proposed: CGPoint,
        radius: CGFloat,
        boundsWidth: CGFloat,
        boundsHeight: CGFloat
    ) -> CGPoint {
        let minX = radius
        let maxX = boundsWidth - radius
        let minY = radius
        let maxY = boundsHeight - radius

        let cx: CGFloat
        if minX <= maxX {
            cx = min(max(proposed.x, minX), maxX)
        } else {
            cx = boundsWidth / 2
        }

        let cy: CGFloat
        if minY <= maxY {
            cy = min(max(proposed.y, minY), maxY)
        } else {
            cy = boundsHeight / 2
        }

        return CGPoint(x: cx, y: cy)
    }

    func show(menu: PieMenu, itemsOverride: [PieMenuItem]? = nil, navigationHotkeyForChordRepeat: HotkeyConfig? = nil) {
        let items = itemsOverride ?? menu.items
        guard !items.isEmpty else { return }

        // Защита от повторного `show()` без `hide()`: иначе вешаются лишние мониторы и «висит» прежнее окно.
        if window != nil {
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
        let windowSize = screen.visibleFrame.size
        let windowOrigin = screen.visibleFrame.origin

        let window = OverlayPanel(
            contentRect: NSRect(origin: windowOrigin, size: windowSize),
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
        // Пункты меню должны всегда выглядеть одинаково, независимо от темы macOS: фиксируем тёмный appearance,
        // чтобы Liquid Glass / .ultraThinMaterial и системные тонировки не переключались вслед за системой.
        window.appearance = NSAppearance(named: .darkAqua)

        let layoutView = NSView(frame: NSRect(origin: .zero, size: windowSize))
        window.contentView = layoutView
        window.collectionBehavior = [
            .moveToActiveSpace,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]

        window.layoutIfNeeded()

        let sortedItems = items.sorted { $0.sectorIndex < $1.sectorIndex }
        displayedItems = sortedItems
        displayedShortcutLabels = PieMenu.resolvedShortcutLabels(for: sortedItems)
        let hs = PieMenuHighlightState()
        hs.highlightedIndex = menu.isRunningAppsMenu ? 0 : nil
        highlightState = hs
        displayedMenuId = menu.id

        let mouseInWindowBase = window.mouseLocationOutsideOfEventStream
        let contentHeight = window.contentView?.bounds.height ?? window.frame.height
        let proposedCenter = CGPoint(
            x: mouseInWindowBase.x,
            y: contentHeight - mouseInWindowBase.y
        )
        let menuCenter = Self.clampedMenuCenter(
            proposed: proposedCenter,
            radius: CGFloat(menu.effectiveMenuRadius),
            boundsWidth: windowSize.width,
            boundsHeight: contentHeight
        )

        let menuView = PieMenuView(
            items: sortedItems,
            radius: menu.effectiveMenuRadius,
            innerRadius: menu.effectiveInnerRadius,
            iconDistance: menu.iconDistance,
            iconSize: menu.effectiveIconSize,
            rotationDegrees: menu.rotationDegrees,
            liquidGlass: menu.liquidGlass,
            menuCenter: menuCenter,
            pawDecorationEnabled: menu.pawDecorationEnabled,
            pawSizeScale: menu.pawSizeScale,
            pawRadialInset: menu.pawRadialInset,
            centerCatScale: menu.centerCatScale,
            shortcutDigitSizeScale: menu.shortcutDigitSizeScale,
            shortcutDigitInsetLeftScale: menu.shortcutDigitInsetLeftScale,
            shortcutDigitInsetRightScale: menu.shortcutDigitInsetRightScale,
            shortcutDigitOpacity: menu.shortcutDigitOpacity,
            shortcutDigitColorHex: menu.shortcutDigitColorHex,
            innerCircleHighlightsFirstSector: menu.isRunningAppsMenu,
            appearsInstantly: menu.isRunningAppsMenu,
            highlightState: hs,
            hapticFeedbackEnabled: ConfigManager.shared.configuration.hapticFeedbackEnabled,
            onItemSelected: { [weak self] item in
                self?.onItemSelected?(item)
            },
            onHoverChanged: { [weak self] item in
                self?.onHoverChanged?(item)
            },
            onDismiss: { [weak self] in
                self?.hide()
            }
        )

        let hostingView = NSHostingView(rootView: menuView)
        window.contentView = hostingView

        self.window = window

        chordNavigationHotkey = navigationHotkeyForChordRepeat
        chordNavigationIgnoreUntilMainKeyUp = navigationHotkeyForChordRepeat != nil

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            switch event.type {
            case .keyUp:
                if let chord = self.chordNavigationHotkey,
                   event.keyCode == UInt16(chord.keyCode) {
                    self.chordNavigationIgnoreUntilMainKeyUp = false
                }
                return event
            case .keyDown:
                if event.keyCode == UInt16(KeyCodes.escape) {
                    self.hide()
                    return nil
                }
                if let customIndex = self.displayedItemIndex(forPressedKey: event.charactersIgnoringModifiers)
                    ?? self.displayedItemIndex(forPressedKey: event.characters),
                   let item = self.displayedItem(forQuickSelectIndex: customIndex) {
                    self.onItemSelected?(item)
                    return nil
                }
                if let quickSelectIndex = Self.quickSelectIndexByKeyCode[event.keyCode],
                   quickSelectIndex < self.displayedShortcutLabels.count,
                   self.displayedShortcutLabels[quickSelectIndex] != nil,
                   let item = self.displayedItem(forQuickSelectIndex: quickSelectIndex) {
                    self.onItemSelected?(item)
                    return nil
                }
                if let chord = self.chordNavigationHotkey,
                   chord.matchesKeyDownForChordRepeat(event),
                   !self.chordNavigationIgnoreUntilMainKeyUp {
                    self.advanceRunningAppsSelection()
                    return nil
                }
                return event
            default:
                return event
            }
        }

        // Клик вне секторов закрывает меню через SwiftUI `onDismiss` на полноэкранном оверлее
        // (без global mouse monitor / Accessibility).

        // Отключение монитора / смена разрешения во время показа оставляют оверлей в призрачных координатах.
        screenParamsObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.hide() }
        }

        window.orderFrontRegardless()
        window.makeKey()
        showMouseLocation = NSEvent.mouseLocation
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
        highlightState = nil
        displayedItems = []
        displayedShortcutLabels = []
        displayedMenuId = nil
        chordNavigationHotkey = nil
        chordNavigationIgnoreUntilMainKeyUp = false
        lastChordAdvanceUptime = 0
        showMouseLocation = nil
        window?.orderOut(nil)
        window = nil
        onHide?()
    }
}
