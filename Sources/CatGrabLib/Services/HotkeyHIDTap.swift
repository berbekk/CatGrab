import Carbon
import CoreGraphics
import Foundation
import os.log

/// Глобальный HID-перехват для хоткеев, которые Carbon не видит: ⌘Tab, Fn/Globe.
final class HotkeyHIDTap {
    static weak var shared: HotkeyHIDTap?

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
    private var inputState = HotkeyInputState()
    private var generation = UUID()
    private var receivesKeyEvents = false

    /// Есть ли активные хоткеи, которые без «Универсального доступа» работать не будут.
    static func requiresAccessibility(menus: [PieMenu]) -> Bool {
        menus.contains { menu in
            guard !menu.hotkey.isEmpty, menu.hotkey.prefersHIDEventTap else { return false }
            if menu.isDynamicMenu && !menu.runningAppsMenuEnabled { return false }
            return true
        }
    }

    func start(menus: [PieMenu]) {
        stop()

        var grouped: [String: Binding] = [:]
        for (index, menu) in menus.enumerated() {
            let hotkey = menu.hotkey
            guard !hotkey.isEmpty, hotkey.prefersHIDEventTap else { continue }
            if menu.isDynamicMenu && !menu.runningAppsMenuEnabled { continue }
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
        receivesKeyEvents = deliversKeyEvents

        claimsCommandTab = hasBinding(keyCode: KeyCodes.tab, carbonModifiers: CarbonModifiers.command)
        claimsCommandShiftTab = hasBinding(
            keyCode: KeyCodes.tab,
            carbonModifiers: CarbonModifiers.command | CarbonModifiers.shift
        )
        secureInputActive = IsSecureEventInputEnabled()
        applyNativeSwitcherState()
        if claimsCommandTab || claimsCommandShiftTab {
            startSecureInputWatch()
        }
    }

    // MARK: - Secure Event Input

    /// Пока какое-то приложение (поле пароля, менеджер паролей, иногда сам `loginwindow` после входа)
    /// держит «безопасный ввод», macOS не отдаёт event tap'ам обычные клавиши — только модификаторы.
    /// ⌘Tab до CatGrab не доходит, а системный переключатель мы сами выключили, и ⌘Tab пропадает целиком.
    /// Поэтому на это время возвращаем системный ⌘Tab и забираем его обратно, когда режим выключится.
    /// ⌘Tab дополнительно зарегистрирован через Carbon, а Carbon-хоткеи работают и при «безопасном вводе».
    /// Учитываем подстраховку отдельно для ⌘Tab и ⌘⇧Tab: регистрация одного не гарантирует второе.
    /// Ставится `HotkeyManager` после `start`, поэтому состояние переприменяем сразу.
    private var carbonBackups: Set<Int> = []

    func addCarbonBackup(_ hotkey: HotkeyConfig) {
        carbonBackups.insert(hotkey.carbonModifiers)
        applyNativeSwitcherState()
    }
    private var claimsCommandTab = false
    private var claimsCommandShiftTab = false
    private var secureInputActive = false
    private var secureInputTimer: Timer?
    private static let secureInputPollInterval: TimeInterval = 1

    private func applyNativeSwitcherState() {
        guard port != nil else { return }
        guard isRunning, receivesKeyEvents else {
            NativeAppSwitcher.restore()
            return
        }
        NativeAppSwitcher.suspend(
            commandTab: claimsCommandTab && (!secureInputActive || carbonBackups.contains(CarbonModifiers.command)),
            commandShiftTab: claimsCommandShiftTab
                && (!secureInputActive || carbonBackups.contains(CarbonModifiers.command | CarbonModifiers.shift))
        )
    }

    private func startSecureInputWatch() {
        if secureInputActive {
            PieLog.hotkey.notice("secure event input is on at start")
        }
        let timer = Timer(timeInterval: Self.secureInputPollInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            let active = IsSecureEventInputEnabled()
            guard active != self.secureInputActive || !self.isRunning else { return }
            self.secureInputActive = active
            self.applyNativeSwitcherState()
        }
        timer.tolerance = Self.secureInputPollInterval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        secureInputTimer = timer
    }

    private func hasBinding(keyCode: Int, carbonModifiers: Int) -> Bool {
        bindings.contains { !$0.isStandaloneFn && $0.keyCode == keyCode && $0.carbonModifiers == carbonModifiers }
    }

    /// Tap создан и активен.
    var isRunning: Bool { port.map { CFMachPortIsValid($0) && CGEvent.tapIsEnabled(tap: $0) } ?? false }

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
        secureInputTimer?.invalidate()
        secureInputTimer = nil
        generation = UUID()
        carbonBackups = []
        claimsCommandTab = false
        claimsCommandShiftTab = false
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
        inputState = HotkeyInputState()
        receivesKeyEvents = false
        if HotkeyHIDTap.shared === self {
            HotkeyHIDTap.shared = nil
        }
    }

    deinit {
        stop()
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            PieLog.hotkey.error("event tap disabled by system (\(type.rawValue)), re-enabling")
            inputState = HotkeyInputState()
            generation = UUID()
            NativeAppSwitcher.restore()
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            applyNativeSwitcherState()
            return Unmanaged.passUnretained(event)
        }

        if type == .flagsChanged {
            let flags = event.flags
            let action = inputState.fn(
                keyCode: Int(event.getIntegerValueField(.keyboardEventKeycode)),
                isDown: flags.contains(.maskSecondaryFn),
                hasOtherModifiers: !flags.isDisjoint(with: [.maskCommand, .maskShift, .maskAlternate, .maskControl]),
                indices: bindings.filter(\.isStandaloneFn).flatMap(\.indices)
            )
            return dispatch(action, event: event)
        }

        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let carbon = CarbonModifiers.carbon(from: event.flags) & relevantModifierMask
        let binding = bindings.first {
            !$0.isStandaloneFn && $0.keyCode == keyCode && $0.carbonModifiers == carbon
        }
        let action = inputState.key(
            keyCode: keyCode,
            isDown: type == .keyDown,
            isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
            matching: binding?.indices
        )
        return dispatch(action, event: event)
    }

    private func dispatch(_ action: HotkeyInputState.Action, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard action != .passThrough else { return Unmanaged.passUnretained(event) }
        guard action != .consume else { return nil }
        let token = generation
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == token else { return }
            switch action {
            case .pressed(let indices): self.onPressed?(indices)
            case .released(let indices): self.onReleased?(indices)
            case .passThrough, .consume: break
            }
        }
        return nil
    }

    private var relevantModifierMask: Int {
        CarbonModifiers.command | CarbonModifiers.shift | CarbonModifiers.option
            | CarbonModifiers.control | CarbonModifiers.fn
    }

}
