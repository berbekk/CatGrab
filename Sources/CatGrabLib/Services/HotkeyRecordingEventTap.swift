import AppKit
import Foundation

final class FnGlobeRecordingState {
    var modifierDown = false
}

/// Локальный захват клавиш при записи хоткея (без CGEvent tap / Input Monitoring).
final class HotkeyRecordingEventTap {
    private var monitors: [Any] = []
    private let fnState = FnGlobeRecordingState()

    var onCapturedKeyDown: ((_ keyCode: Int, _ carbonModifiers: Int, _ fnGlobeHeld: Bool) -> Void)?
    var onEscape: (() -> Void)?

    func start() -> Bool {
        stop()

        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            if event.keyCode == UInt16(HotkeyConfig.fnKeyVirtualCode) {
                self?.fnState.modifierDown = event.modifierFlags.contains(.function)
            }
            return event
        }) {
            monitors.append(m)
        }

        if let m = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard let self else { return event }
            if event.keyCode == UInt16(KeyCodes.escape) {
                let escape = self.onEscape
                DispatchQueue.main.async { escape?() }
                return nil
            }
            let carbon = CarbonModifiers.carbon(from: event.modifierFlags)
            let fnHeld = self.fnState.modifierDown
            let capture = self.onCapturedKeyDown
            DispatchQueue.main.async {
                capture?(Int(event.keyCode), carbon, fnHeld)
            }
            return nil
        }) {
            monitors.append(m)
        }

        return !monitors.isEmpty
    }

    func stop() {
        for m in monitors {
            NSEvent.removeMonitor(m)
        }
        monitors.removeAll(keepingCapacity: false)
        fnState.modifierDown = false
    }

    deinit {
        stop()
    }
}
