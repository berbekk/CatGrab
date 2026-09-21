import AppKit
import Combine
import Foundation

/// Следит за правами в фоне: пока доступ не выдан — опрашивает часто, после — редко.
/// UI подписывается через `@ObservedObject`, `AppDelegate` — через `$snapshot`.
@MainActor
final class PermissionsMonitor: ObservableObject {
    static let shared = PermissionsMonitor()

    @Published private(set) var snapshot: PermissionsSnapshot

    private var timer: Timer?
    private var activationObserver: NSObjectProtocol?
    private let pendingInterval: TimeInterval = 1.0
    private let grantedInterval: TimeInterval = 5.0

    private init() {
        snapshot = PermissionsSnapshot.current()
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        scheduleTimer()
    }

    func refresh() {
        let fresh = PermissionsSnapshot.current()
        let changed = fresh != snapshot
        snapshot = fresh
        if changed {
            scheduleTimer()
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = snapshot.allRequiredGranted ? grantedInterval : pendingInterval
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        t.tolerance = interval * 0.2
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}
