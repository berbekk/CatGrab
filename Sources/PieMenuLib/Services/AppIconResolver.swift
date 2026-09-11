import AppKit

/// Кэш `NSImage` для bundle id приложений: `NSWorkspace.icon(forFile:)` не бесплатен, а иконки повторяются
/// в превью, пикере, редакторе и сайдбаре. Инвалидируется при `NSWorkspace.didActivateApplicationNotification`.
final class AppIconResolver {
    static let shared = AppIconResolver()

    private struct Entry {
        let image: NSImage?
    }

    private let queue = DispatchQueue(label: "pie.AppIconResolver", attributes: .concurrent)
    private var cache: [String: Entry] = [:]

    private init() {}

    /// Синхронное чтение из кэша, при промахе — разрешение через `NSWorkspace` (main-поток).
    func icon(forBundleIdentifier bundleIdentifier: String) -> NSImage? {
        let key = bundleIdentifier.lowercased()
        if let cached = read(key: key) {
            return cached.image
        }
        let image = Self.loadIcon(forBundleIdentifier: bundleIdentifier)
        write(key: key, entry: Entry(image: image))
        return image
    }

    /// URL-основанная иконка (например, для .app вне Launch Services индекса).
    func icon(forURL url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    func invalidate() {
        queue.async(flags: .barrier) { [weak self] in
            self?.cache.removeAll(keepingCapacity: true)
        }
    }

    private func read(key: String) -> Entry? {
        queue.sync { cache[key] }
    }

    private func write(key: String, entry: Entry) {
        queue.async(flags: .barrier) { [weak self] in
            self?.cache[key] = entry
        }
    }

    private static func loadIcon(forBundleIdentifier bundleIdentifier: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
