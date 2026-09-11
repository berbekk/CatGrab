import CoreGraphics
import Foundation
import os.log

/// Глобальный HID-перехват для хоткеев, которые Carbon не видит: ⌘Tab, Fn/Globe.
final class HotkeyHIDTap {
    static var shared: HotkeyHIDTap?

    var onPressed: (([UInt32]) -> Void)?
    var onReleased: (([UInt32]) -> Void)?

    private struct Binding {
        let keyCode: Int
        let carbonModifiers: Int
        let indices: [UInt32]
        let isStandaloneFn: Bool
    }

    private var bindings: [Binding] = []
    private var port: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var standaloneFnDown = false

    /// Есть ли активные хоткеи, которые без «Универсального доступа» работать не будут.
    static func requiresAccessibility(menus: [PieMenu]) -> Bool {
        menus.contains { menu in
            guard !menu.hotkey.isEmpty, menu.hotkey.prefersHIDEventTap else { return false }
            if menu.isRunningAppsMenu && !menu.runningAppsMenuEnabled { return false }
            return true
        }
    }

    func start(menus: [PieMenu]) {
        stop()

        var grouped: [String: Binding] = [:]
        for (index, menu) in menus.enumerated() {
            let hotkey = menu.hotkey
            guard !hotkey.isEmpty, hotkey.prefersHIDEventTap else { continue }
            if menu.isRunningAppsMenu && !menu.runningAppsMenuEnabled { continue }
            let key = "\(hotkey.keyCode)_\(hotkey.carbonModifiers)"
            if var existing = grouped[key] {
                existing = Binding(
                    keyCode: existing.keyCode,
                    carbonModifiers: existing.carbonModifiers,
                    indices: existing.indices + [UInt32(index)],
                    isStandaloneFn: existing.isStandaloneFn
                )
                grouped[key] = existing
            } else {
                grouped[key] = Binding(
                    keyCode: hotkey.keyCode,
                    carbonModifiers: hotkey.carbonModifiers,
                    indices: [UInt32(index)],
                    isStandaloneFn: hotkey.keyCode == HotkeyConfig.fnKeyVirtualCode && hotkey.carbonModifiers == 0
                )
            }
        }
        bindings = Array(grouped.values)
        guard !bindings.isEmpty else { return }

        HotkeyHIDTap.shared = self

        let mask =
            (1 as CGEventMask) << CGEventType.keyDown.rawValue
            | (1 as CGEventMask) << CGEventType.keyUp.rawValue
            | (1 as CGEventMask) << CGEventType.flagsChanged.rawValue

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, _ in
                HotkeyHIDTap.shared?.handle(type: type, event: event) ?? Unmanaged.passUnretained(event)
            },
            userInfo: nil
        ) else {
            PieLog.hotkey.error("HID event tap unavailable: accessibility not granted")
            return
        }

        port = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        NativeAppSwitcher.suspend(
            commandTab: hasBinding(keyCode: KeyCodes.tab, carbonModifiers: CarbonModifiers.command),
            commandShiftTab: hasBinding(
                keyCode: KeyCodes.tab,
                carbonModifiers: CarbonModifiers.command | CarbonModifiers.shift
            )
        )
    }

    private func hasBinding(keyCode: Int, carbonModifiers: Int) -> Bool {
        bindings.contains { !$0.isStandaloneFn && $0.keyCode == keyCode && $0.carbonModifiers == carbonModifiers }
    }

    /// Tap создан и активен.
    var isRunning: Bool { port != nil }

    /// WindowServer молча вырезает keyDown/keyUp из маски tap'а, если процессу не выдан
    /// «Мониторинг ввода». Проверяем фактическую маску через `CGGetEventTapList`.
    var deliversKeyEvents: Bool {
        guard port != nil else { return false }
        var count: UInt32 = 0
        CGGetEventTapList(0, nil, &count)
        guard count > 0 else { return false }
        var taps = [CGEventTapInformation](repeating: CGEventTapInformation(), count: Int(count))
        CGGetEventTapList(count, &taps, &count)
        let keyDownBit = (1 as CGEventMask) << CGEventType.keyDown.rawValue
        let pid = getpid()
        return taps.prefix(Int(count)).contains { info in
            info.tappingProcess == pid && info.enabled && (info.eventsOfInterest & keyDownBit) != 0
        }
    }

    func stop() {
        NativeAppSwitcher.restore()
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        runLoopSource = nil
        self.port = nil
        bindings = []
        standaloneFnDown = false
        if HotkeyHIDTap.shared === self {
            HotkeyHIDTap.shared = nil
        }
    }

    deinit {
        stop()
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        if type == .flagsChanged, handleStandaloneFn(type: type, event: event) {
            return nil
        }

        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let carbon = CarbonModifiers.carbon(from: event.flags) & relevantModifierMask
        guard let binding = bindings.first(where: {
            !$0.isStandaloneFn && $0.keyCode == keyCode && $0.carbonModifiers == carbon
        }) else {
            return Unmanaged.passUnretained(event)
        }

        let indices = binding.indices
        DispatchQueue.main.async { [weak self] in
            if type == .keyDown {
                self?.onPressed?(indices)
            } else {
                self?.onReleased?(indices)
            }
        }
        return nil
    }

    private var relevantModifierMask: Int {
        CarbonModifiers.command | CarbonModifiers.shift | CarbonModifiers.option
            | CarbonModifiers.control | CarbonModifiers.fn
    }

    /// Fn/Globe почти всегда приходит как `flagsChanged`, а не как keyDown.
    private func handleStandaloneFn(type: CGEventType, event: CGEvent) -> Bool {
        let fnBindings = bindings.filter(\.isStandaloneFn)
        guard !fnBindings.isEmpty else { return false }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let fnHeld = flags.contains(.maskSecondaryFn)
        let extras =
            flags.contains(.maskCommand)
            || flags.contains(.maskShift)
            || flags.contains(.maskAlternate)
            || flags.contains(.maskControl)
        let looksLikeFnKey = keyCode == HotkeyConfig.fnKeyVirtualCode || (fnHeld && !extras)

        guard looksLikeFnKey else { return false }

        let indices = fnBindings.flatMap(\.indices)
        if fnHeld && !standaloneFnDown {
            standaloneFnDown = true
            DispatchQueue.main.async { [weak self] in self?.onPressed?(indices) }
            return true
        }
        if !fnHeld && standaloneFnDown {
            standaloneFnDown = false
            DispatchQueue.main.async { [weak self] in self?.onReleased?(indices) }
            return true
        }
        return fnHeld
    }
}
