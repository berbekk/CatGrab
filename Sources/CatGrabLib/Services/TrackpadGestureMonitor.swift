import AppKit
import Foundation
import IOKit
import os.log

/// Касание трекпада несколькими пальцами через приватный `MultitouchSupport.framework`.
/// Публичного API для касаний вне своего окна нет: `NSEvent` отдаёт жесты только активному приложению,
/// а event tap не видит пальцы. Фреймворк грузим через `dlopen`, поэтому если Apple его уберёт или
/// поменяет, приложение не упадёт на старте — жест просто не заработает.
/// Прав «Универсальный доступ» / «Мониторинг ввода» не требует.
final class TrackpadGestureMonitor {
    /// C-колбэк без контекста — обращается к активному монитору через это поле.
    fileprivate static var active: TrackpadGestureMonitor?

    /// Сколько пальцев было в распознанном касании.
    var onTap: ((Int) -> Void)?

    /// Какие касания распознавать: у каждого меню может быть своё число пальцев.
    private var fingerCounts: [Int] = []
    private var devices: CFArray?
    /// По распознавателю на устройство и на число пальцев.
    private var recognizers: [UInt: [Int: TrackpadTapRecognizer]] = [:]
    private let lock = NSLock()
    private var wakeObserver: NSObjectProtocol?
    private var notifyPort: IONotificationPortRef?
    private var deviceAddedIterator: io_iterator_t = 0
    private var restartWorkItem: DispatchWorkItem?

    var isRunning: Bool { devices != nil }

    func start(fingerCounts: Set<Int>) {
        stop()
        let supported = fingerCounts.filter(TrackpadGesture.supportedFingerCounts.contains).sorted()
        guard !supported.isEmpty else { return }
        guard let api = MultitouchAPI.shared else {
            PieLog.hotkey.error("MultitouchSupport unavailable, trackpad gesture disabled")
            return
        }
        self.fingerCounts = supported
        Self.active = self
        startDevices(api: api)
        observeDeviceChanges()
    }

    func stop() {
        stopDevices()
        restartWorkItem?.cancel()
        restartWorkItem = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        if deviceAddedIterator != 0 {
            IOObjectRelease(deviceAddedIterator)
            deviceAddedIterator = 0
        }
        if let notifyPort {
            IONotificationPortDestroy(notifyPort)
            self.notifyPort = nil
        }
        fingerCounts = []
        if Self.active === self {
            Self.active = nil
        }
    }

    deinit {
        stop()
    }

    // MARK: - Devices

    private func startDevices(api: MultitouchAPI) {
        guard let list = api.createList()?.takeRetainedValue() else { return }
        let count = CFArrayGetCount(list)
        for i in 0..<count {
            guard let device = CFArrayGetValueAtIndex(list, i) else { continue }
            let ref = UnsafeMutableRawPointer(mutating: device)
            api.registerCallback(ref, trackpadContactFrameCallback)
            api.start(ref, 0)
        }
        devices = list
        let counts = fingerCounts.map(String.init).joined(separator: ",")
        PieLog.hotkey.notice("trackpad gesture: \(counts, privacy: .public)-finger tap on \(count) device(s)")
    }

    private func stopDevices() {
        guard let list = devices, let api = MultitouchAPI.shared else {
            devices = nil
            return
        }
        for i in 0..<CFArrayGetCount(list) {
            guard let device = CFArrayGetValueAtIndex(list, i) else { continue }
            let ref = UnsafeMutableRawPointer(mutating: device)
            api.unregisterCallback(ref, trackpadContactFrameCallback)
            api.stop(ref)
        }
        devices = nil
        lock.lock()
        recognizers = [:]
        lock.unlock()
    }

    /// После сна устройства перестают присылать кадры, а подключённый позже Magic Trackpad
    /// не попадает в уже полученный список — в обоих случаях собираем список заново.
    private func observeDeviceChanges() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRestart()
        }

        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        notifyPort = port
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            IONotificationPortGetRunLoopSource(port).takeUnretainedValue(),
            .commonModes
        )
        let status = IOServiceAddMatchingNotification(
            port,
            kIOFirstMatchNotification,
            IOServiceMatching("AppleMultitouchDevice"),
            { _, iterator in
                TrackpadGestureMonitor.drain(iterator)
                DispatchQueue.main.async { TrackpadGestureMonitor.active?.scheduleRestart() }
            },
            nil,
            &deviceAddedIterator
        )
        // Итератор надо вычерпать, иначе уведомления о новых устройствах не придут.
        if status == KERN_SUCCESS {
            Self.drain(deviceAddedIterator)
        }
    }

    private static func drain(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            IOObjectRelease(service)
        }
    }

    /// Устройство появляется в IOKit раньше, чем MultitouchSupport готов с ним работать.
    private func scheduleRestart() {
        restartWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, !self.fingerCounts.isEmpty, let api = MultitouchAPI.shared else { return }
            self.stopDevices()
            self.startDevices(api: api)
        }
        restartWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Timings.trackpadDeviceRestartDelay, execute: item)
    }

    // MARK: - Frames

    /// Вызывается на внутреннем потоке MultitouchSupport, по кадру на каждое устройство.
    fileprivate func handleFrame(device: UnsafeMutableRawPointer?, touches: [TrackpadTapRecognizer.Touch], timestamp: Double) {
        let key = UInt(bitPattern: device)
        lock.lock()
        var deviceRecognizers = recognizers[key] ?? [:]
        var tapped: [Int] = []
        for count in fingerCounts {
            var recognizer = deviceRecognizers[count] ?? TrackpadTapRecognizer(fingerCount: count)
            if recognizer.process(touches: touches, timestamp: timestamp) {
                tapped.append(count)
            }
            deviceRecognizers[count] = recognizer
        }
        recognizers[key] = deviceRecognizers
        lock.unlock()
        // Распознаватель срабатывает, только если пальцев было ровно столько, — больше одного числа за раз не бывает.
        guard let count = tapped.first else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onTap?(count)
        }
    }
}

// MARK: - MultitouchSupport

private typealias MTContactFrameCallback = @convention(c) (
    UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32
) -> Int32

private let trackpadContactFrameCallback: MTContactFrameCallback = { device, data, count, timestamp, _ in
    guard let monitor = TrackpadGestureMonitor.active else { return 0 }
    var touches: [TrackpadTapRecognizer.Touch] = []
    if let data, count > 0 {
        touches.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            let finger = data.advanced(by: i * MTFingerLayout.stride)
            let state = finger.load(fromByteOffset: MTFingerLayout.stateOffset, as: Int32.self)
            guard MTFingerLayout.touchingStates.contains(state) else { continue }
            touches.append(TrackpadTapRecognizer.Touch(
                id: finger.load(fromByteOffset: MTFingerLayout.identifierOffset, as: Int32.self),
                x: finger.load(fromByteOffset: MTFingerLayout.normalizedXOffset, as: Float.self),
                y: finger.load(fromByteOffset: MTFingerLayout.normalizedYOffset, as: Float.self)
            ))
        }
    }
    monitor.handleFrame(device: device, touches: touches, timestamp: timestamp)
    return 0
}

/// Раскладка структуры пальца (`MTTouch`) в кадре MultitouchSupport — стабильна с macOS 10.x.
private enum MTFingerLayout {
    static let stride = 96
    static let identifierOffset = 16
    static let stateOffset = 20
    static let normalizedXOffset = 32
    static let normalizedYOffset = 36
    /// 3 — палец коснулся, 4 — касается, 5 — отрывается. Остальные — палец лишь над поверхностью.
    static let touchingStates: ClosedRange<Int32> = 3...5
}

private struct MultitouchAPI {
    typealias CreateList = @convention(c) () -> Unmanaged<CFArray>?
    typealias RegisterCallback = @convention(c) (UnsafeMutableRawPointer, MTContactFrameCallback) -> Void
    typealias DeviceStart = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void
    typealias DeviceStop = @convention(c) (UnsafeMutableRawPointer) -> Void

    let createList: CreateList
    let registerCallback: RegisterCallback
    let unregisterCallback: RegisterCallback
    let start: DeviceStart
    let stop: DeviceStop

    static let shared: MultitouchAPI? = {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_LAZY) else { return nil }
        func symbol<T>(_ name: String, as _: T.Type) -> T? {
            guard let sym = dlsym(handle, name) else { return nil }
            return unsafeBitCast(sym, to: T.self)
        }
        guard let createList = symbol("MTDeviceCreateList", as: CreateList.self),
              let register = symbol("MTRegisterContactFrameCallback", as: RegisterCallback.self),
              let unregister = symbol("MTUnregisterContactFrameCallback", as: RegisterCallback.self),
              let start = symbol("MTDeviceStart", as: DeviceStart.self),
              let stop = symbol("MTDeviceStop", as: DeviceStop.self) else { return nil }
        return MultitouchAPI(
            createList: createList,
            registerCallback: register,
            unregisterCallback: unregister,
            start: start,
            stop: stop
        )
    }()
}
