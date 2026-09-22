import AppKit
import Foundation

/// Помнит, в каком порядке пользователь переключался между приложениями: какое было активным до
/// последней смены фокуса (откуда перешли) и все недавние — для меню запущенных с ограничением.
enum RunningAppsActivationHistory {
    private static var observer: NSObjectProtocol?
    private static var lastKnownActiveBundleIdentifier: String?

    static private(set) var bundleIdentifierBeforeLastActivation: String?

    /// От самого недавнего к давнему; CatGrab сюда не попадает. Приложения, к которым не переходили
    /// с момента запуска CatGrab, в списке отсутствуют.
    static private(set) var recentBundleIdentifiers: [String] = []

    private static let recentLimit = 64

    static func startObservingIfNeeded() {
        guard observer == nil else { return }
        lastKnownActiveBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if let current = lastKnownActiveBundleIdentifier, current != Bundle.main.bundleIdentifier {
            recentBundleIdentifiers = [current]
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            let newBid = app.bundleIdentifier
            if newBid == Bundle.main.bundleIdentifier {
                return
            }
            bundleIdentifierBeforeLastActivation = lastKnownActiveBundleIdentifier
            lastKnownActiveBundleIdentifier = newBid
            if let newBid {
                noteActivated(newBid)
            }
        }
    }

    static func noteActivated(_ bundleIdentifier: String) {
        recentBundleIdentifiers.removeAll { $0 == bundleIdentifier }
        recentBundleIdentifiers.insert(bundleIdentifier, at: 0)
        if recentBundleIdentifiers.count > recentLimit {
            recentBundleIdentifiers.removeLast(recentBundleIdentifiers.count - recentLimit)
        }
    }
}
