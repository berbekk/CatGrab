import AppKit

/// Картинки секторов из файлов (свои иконки и фавиконы). Раньше `IconView` читал и декодировал файл
/// при каждой перерисовке — то есть на каждом наведении, для каждого такого сектора; кольцо из
/// фавиконов заметно подтормаживало. Здесь файл декодируется один раз.
final class FileIconCache {
    static let shared = FileIconCache()

    private let cache = NSCache<NSString, NSImage>()
    private let missing = NSCache<NSString, NSNumber>()

    private init() {
        cache.countLimit = 256
        missing.countLimit = 256
    }

    /// `nil` — файла нет или он не картинка. Отсутствие тоже запоминается: иначе проверка файла шла бы
    /// на каждую перерисовку. Файл, который появится позже, подхватится после `invalidate`.
    func image(atPath path: String) -> NSImage? {
        let key = path as NSString
        if let image = cache.object(forKey: key) { return image }
        if missing.object(forKey: key) != nil { return nil }
        guard FileManager.default.fileExists(atPath: path), let image = NSImage(contentsOfFile: path) else {
            missing.setObject(true, forKey: key)
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }

    /// Файл записан заново (загружен фавикон, выбрана другая картинка по тому же пути).
    func invalidate(path: String) {
        cache.removeObject(forKey: path as NSString)
        missing.removeObject(forKey: path as NSString)
    }

    /// Прогреть картинки секторов заранее — чтобы первое открытие меню не ждало диска.
    func prewarm(paths: [String]) {
        for path in paths {
            _ = image(atPath: path)
        }
    }
}
