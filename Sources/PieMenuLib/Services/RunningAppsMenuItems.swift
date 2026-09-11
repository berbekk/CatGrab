import AppKit
import CryptoKit
import Foundation

enum RunningAppsMenuItems {
    /// Стабильный UUID для строк динамического меню, чтобы SwiftUI не пересоздавал секторы при каждом `body`.
    private static func stableItemID(bundleIdentifier: String, processIdentifier: pid_t) -> UUID {
        let key = "\(bundleIdentifier)\u{1D}\(processIdentifier)"
        let digest = SHA256.hash(data: Data(key.utf8))
        let b = Array(digest.prefix(16))
        return UUID(
            uuid: (
                b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]
            )
        )
    }

    /// Собирает секторы для меню типа «запущенные приложения».
    static func build(for menu: PieMenu) -> [PieMenuItem] {
        guard menu.kind == .runningApps else {
            return menu.items.sorted { $0.sectorIndex < $1.sectorIndex }
        }

        let excludedLower = Set(menu.runningAppsExcludedBundleIds.map { $0.lowercased() })
        let selfBundle = Bundle.main.bundleIdentifier

        var apps = NSWorkspace.shared.runningApplications.filter { app in
            guard app.activationPolicy == .regular,
                  let bid = app.bundleIdentifier,
                  !bid.isEmpty else { return false }
            if bid == selfBundle { return false }
            if excludedLower.contains(bid.lowercased()) { return false }
            return true
        }

        apps.sort { a, b in
            let na = a.localizedName ?? a.bundleIdentifier ?? ""
            let nb = b.localizedName ?? b.bundleIdentifier ?? ""
            return na.localizedCaseInsensitiveCompare(nb) == .orderedAscending
        }

        let preferredBid = RunningAppsActivationHistory.bundleIdentifierBeforeLastActivation
        let frontBid = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if let preferredBid,
           preferredBid != frontBid,
           let pIdx = apps.firstIndex(where: { $0.bundleIdentifier == preferredBid }) {
            let preferred = apps.remove(at: pIdx)
            apps.insert(preferred, at: 0)
        }

        return apps.enumerated().map { index, app in
            let bid = app.bundleIdentifier ?? ""
            let title = app.localizedName ?? bid
            return PieMenuItem(
                id: stableItemID(bundleIdentifier: bid, processIdentifier: app.processIdentifier),
                title: title,
                icon: "app.fill",
                action: .launchApp(bundleIdentifier: bid),
                color: PieMenuItem.paletteColor(for: index),
                sectorIndex: index
            )
        }
    }
}
