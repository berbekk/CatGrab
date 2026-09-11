import Foundation
import AppKit

struct AppDescriptor {
    let bundleIdentifier: String
    let displayName: String
}

enum AppDescriptorResolver {
    static func resolve(from url: URL) -> AppDescriptor? {
        let bundle = Bundle(url: url)

        let bundleIdentifier = bundle?.bundleIdentifier
            ?? bundleIdentifierFromInfoPlist(at: url)
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else { return nil }

        let displayName = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle?.infoDictionary?["CFBundleName"] as? String
            ?? FileManager.default.displayName(atPath: url.path)

        return AppDescriptor(bundleIdentifier: bundleIdentifier, displayName: displayName)
    }

    private static func bundleIdentifierFromInfoPlist(at appURL: URL) -> String? {
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let info = NSDictionary(contentsOf: infoPlistURL) as? [String: Any] else { return nil }
        return info["CFBundleIdentifier"] as? String
    }
}
