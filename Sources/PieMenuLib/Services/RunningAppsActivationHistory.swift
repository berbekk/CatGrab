import AppKit
import Foundation

/// Запоминает bundle id приложения, которое было активным до последней смены фокуса (откуда перешли).
enum RunningAppsActivationHistory {
    private static var observer: NSObjectProtocol?
    private static var lastKnownActiveBundleIdentifier: String?

    static private(set) var bundleIdentifierBeforeLastActivation: String?

    static func startObservingIfNeeded() {
        guard observer == nil else { return }
        lastKnownActiveBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
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
        }
    }
}
