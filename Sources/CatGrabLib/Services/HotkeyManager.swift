import Carbon
import Foundation

/// Глобальные горячие клавиши через Carbon `RegisterEventHotKey` (совместимо с App Sandbox).
final class HotkeyManager {
    static var shared: HotkeyManager?

    /// Индексы меню (`menus[i]`), у которых совпало одно и то же физическое сочетание клавиш.
    var onHotkeyPressed: (([UInt32]) -> Void)?
    var onHotkeyReleased: (([UInt32]) -> Void)?

    /// Индексы меню, для которых Carbon не зарегистрировал хоткей (Fn-only и т.п.).
    private(set) var failedRegistrationMenuIndices: [Int] = []

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var hotkeyIDToMenuIndices: [UInt32: [UInt32]] = [:]
    private var handlerRef: EventHandlerRef?

    private var hidTap: HotkeyHIDTap?

    /// HID-tap поднят, но система не передаёт в него клавиши — права выданы не полностью
    /// или WindowServer ещё держит старое состояние процесса (нужен перезапуск).
    var hidTapIsRunningWithoutKeyEvents: Bool {
        guard let hidTap, hidTap.isRunning else { return false }
        return !hidTap.deliversKeyEvents
    }

    func registerAll(menus: [PieMenu]) {
        unregisterAll()
        HotkeyManager.shared = self
        failedRegistrationMenuIndices = []

        if hidTap == nil {
            hidTap = HotkeyHIDTap()
        }
        hidTap?.onPressed = { [weak self] indices in
            self?.onHotkeyPressed?(indices)
        }
        hidTap?.onReleased = { [weak self] indices in
            self?.onHotkeyReleased?(indices)
        }
        hidTap?.start(menus: menus)

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus in
                guard let event = event else { return noErr }

                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                let carbonID = hotKeyID.id
                let indices = HotkeyManager.shared?.hotkeyIDToMenuIndices[carbonID] ?? [carbonID]
                let eventKind = GetEventKind(event)
                if eventKind == UInt32(kEventHotKeyPressed) {
                    HotkeyManager.shared?.onHotkeyPressed?(indices)
                } else if eventKind == UInt32(kEventHotKeyReleased) {
                    HotkeyManager.shared?.onHotkeyReleased?(indices)
                }
                return noErr
            },
            2,
            &eventTypes,
            nil,
            &handlerRef
        )

        struct HotkeyEntry {
            let index: Int
            let keyCode: Int
            let carbonModifiers: Int
        }
        var entries: [HotkeyEntry] = []
        for (index, menu) in menus.enumerated() {
            if menu.hotkey.isEmpty { continue }
            if menu.isDynamicMenu && !menu.runningAppsMenuEnabled { continue }
            // Fn нельзя выразить через Carbon. ⌘Tab регистрируем и там: tap его поглощает, поэтому
            // дважды не сработает, а при «безопасном вводе» tap не получает клавиш, и тогда
            // срабатывает Carbon — он в этом режиме работает (см. `HotkeyHIDTap.carbonBacksUpCommandTab`).
            if menu.hotkey.prefersHIDEventTap && !menu.hotkey.canUseCarbonBackup { continue }
            entries.append(HotkeyEntry(
                index: index,
                keyCode: menu.hotkey.keyCode,
                carbonModifiers: menu.hotkey.carbonModifiers
            ))
        }

        var groups: [[HotkeyEntry]] = []
        var groupKeyToIndex: [String: Int] = [:]
        for e in entries {
            let key = "\(e.keyCode)_\(e.carbonModifiers)"
            if let gi = groupKeyToIndex[key] {
                groups[gi].append(e)
            } else {
                groupKeyToIndex[key] = groups.count
                groups.append([e])
            }
        }

        for group in groups {
            let primary = group[0]
            let carbonID = UInt32(primary.index)
            let menuIndices = group.map { UInt32($0.index) }
            let ok = registerCarbonHotkey(
                hotkeyID: carbonID,
                keyCode: UInt32(primary.keyCode),
                carbonModifiers: UInt32(primary.carbonModifiers)
            )
            recordRegistration(
                ok: ok,
                hotkey: HotkeyConfig(keyCode: primary.keyCode, carbonModifiers: primary.carbonModifiers),
                carbonID: carbonID,
                menuIndices: menuIndices
            )
        }
    }

    /// Carbon-подстраховка ⌘Tab необязательна: если не зарегистрировалась, меню всё равно работает
    /// через HID tap, поэтому в список ошибок регистрации её не записываем.
    private func recordRegistration(ok: Bool, hotkey: HotkeyConfig, carbonID: UInt32, menuIndices: [UInt32]) {
        if ok {
            hotkeyIDToMenuIndices[carbonID] = menuIndices
        }
        if hotkey.canUseCarbonBackup {
            PieLog.hotkey.notice("carbon backup for ⌘Tab-style hotkey registered=\(ok)")
            if ok { hidTap?.carbonBacksUpCommandTab = true }
        } else if !ok {
            failedRegistrationMenuIndices.append(contentsOf: menuIndices.map(Int.init))
        }
    }

    @discardableResult
    private func registerCarbonHotkey(hotkeyID: UInt32, keyCode: UInt32, carbonModifiers: UInt32) -> Bool {
        let hotKeyID = EventHotKeyID(signature: 0x50494521, id: hotkeyID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            hotKeyRefs[hotkeyID] = ref
            return true
        }
        return false
    }

    func unregisterAll() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll(keepingCapacity: false)
        hotkeyIDToMenuIndices.removeAll(keepingCapacity: false)
        failedRegistrationMenuIndices = []
        if let handler = handlerRef {
            RemoveEventHandler(handler)
            handlerRef = nil
        }
        hidTap?.stop()
    }

    deinit {
        unregisterAll()
    }
}
