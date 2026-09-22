import AppKit

/// Кэш `NSImage` для bundle id приложений: `NSWorkspace.icon(forFile:)` не бесплатен, а иконки повторяются
/// в превью, пикере, редакторе и сайдбаре. Запоминает и то, что приложения нет: сектор с ним
/// показывается приглушённым, а не молча ничего не делает при выборе.
final class AppIconResolver {
    static let shared = AppIconResolver()

    private struct Entry {
        let url: URL?
        let image: NSImage?
    }

    private let queue = DispatchQueue(label: "pie.AppIconResolver", attributes: .concurrent)
    private var cache: [String: Entry] = [:]

    private init() {}

    /// Синхронное чтение из кэша, при промахе — разрешение через `NSWorkspace` (main-поток).
    func icon(forBundleIdentifier bundleIdentifier: String) -> NSImage? {
        entry(forBundleIdentifier: bundleIdentifier).image
    }

    /// Приложение есть на этом Mac (Launch Services знает, где оно).
    func isInstalled(bundleIdentifier: String) -> Bool {
        entry(forBundleIdentifier: bundleIdentifier).url != nil
    }

    /// URL-основанная иконка (например, для .app вне Launch Services индекса).
    func icon(forURL url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    /// Разрешить и декодировать иконки заранее (при запуске и после правки меню), чтобы первое
    /// открытие кольца не искало приложения и не распаковывало картинки прямо перед показом.
    func prewarm(bundleIdentifiers: [String]) {
        for bundleIdentifier in Set(bundleIdentifiers) where !bundleIdentifier.isEmpty {
            guard let image = entry(forBundleIdentifier: bundleIdentifier).image else { continue }
            var rect = CGRect(x: 0, y: 0, width: 64, height: 64)
            _ = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
    }

    /// Приложение запустилось — значит, оно точно установлено: если раньше его не нашли, забываем это.
    func noteLaunched(bundleIdentifier: String) {
        let key = bundleIdentifier.lowercased()
        guard let cached = read(key: key), cached.url == nil else { return }
        queue.async(flags: .barrier) { [weak self] in
            self?.cache.removeValue(forKey: key)
        }
    }

    func invalidate() {
        queue.async(flags: .barrier) { [weak self] in
            self?.cache.removeAll(keepingCapacity: true)
        }
    }

    private func entry(forBundleIdentifier bundleIdentifier: String) -> Entry {
        let key = bundleIdentifier.lowercased()
        if let cached = read(key: key) {
            return cached
        }
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        let entry = Entry(url: url, image: url.map { NSWorkspace.shared.icon(forFile: $0.path) })
        write(key: key, entry: entry)
        return entry
    }

    private func read(key: String) -> Entry? {
        queue.sync { cache[key] }
    }

    private func write(key: String, entry: Entry) {
        queue.async(flags: .barrier) { [weak self] in
            self?.cache[key] = entry
        }
    }
}
