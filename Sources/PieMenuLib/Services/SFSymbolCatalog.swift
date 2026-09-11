import Foundation

struct SFSymbolCategory {
    let key: String
    let name: String
    let icon: String
    let symbols: [String]
}

enum SFSymbolCatalog {
    private static let resourcesPath = "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources"

    static let categories: [SFSymbolCategory] = {
        loadCategories() ?? fallbackCategories
    }()

    private static let allSymbolNames: [String] = {
        var seen = Set<String>()
        var ordered: [String] = []
        for category in categories {
            for name in category.symbols where seen.insert(name).inserted {
                ordered.append(name)
            }
        }
        return ordered
    }()

    /// Имя символа из системного каталога SF Symbols (или запасной вариант, если список пуст).
    static func randomSymbolName() -> String {
        allSymbolNames.randomElement() ?? "sparkles"
    }

    private static func loadCategories() -> [SFSymbolCategory]? {
        let symbolsURL = URL(fileURLWithPath: resourcesPath).appendingPathComponent("symbol_categories.plist")
        let categoriesURL = URL(fileURLWithPath: resourcesPath).appendingPathComponent("categories.plist")

        guard let symbolToCategories = NSDictionary(contentsOf: symbolsURL) as? [String: [String]],
              let categoriesMeta = NSArray(contentsOf: categoriesURL) as? [[String: Any]] else {
            return nil
        }

        var grouped: [String: [String]] = [:]
        for (symbol, categoryKeys) in symbolToCategories {
            for key in categoryKeys where key != "all" {
                grouped[key, default: []].append(symbol)
            }
        }

        for key in grouped.keys {
            grouped[key]?.sort()
        }

        var result: [SFSymbolCategory] = []
        for category in categoriesMeta {
            guard let key = category["key"] as? String, key != "all" else { continue }
            guard let symbols = grouped[key], !symbols.isEmpty else { continue }

            let icon = (category["icon"] as? String) ?? "square.grid.2x2"
            result.append(
                SFSymbolCategory(
                    key: key,
                    name: displayName(for: key),
                    icon: icon,
                    symbols: symbols
                )
            )
        }

        return result.isEmpty ? nil : result
    }

    private static func displayName(for key: String) -> String {
        switch key {
        case "whatsnew": return "What's New"
        case "objectsandtools": return "Objects & Tools"
        case "cameraandphotos": return "Camera & Photos"
        case "privacyandsecurity": return "Privacy & Security"
        case "textformatting": return "Text Formatting"
        default:
            return key
                .replacingOccurrences(of: "and", with: " & ")
                .split(separator: "_")
                .map { part in
                    part.prefix(1).uppercased() + part.dropFirst()
                }
                .joined(separator: " ")
        }
    }

    private static let fallbackCategories: [SFSymbolCategory] = [
        SFSymbolCategory(
            key: "general",
            name: "General",
            icon: "star.fill",
            symbols: [
                "star.fill", "heart.fill", "bookmark.fill", "flag.fill",
                "bell.fill", "tag.fill", "pin.fill", "mappin",
                "eye.fill", "hand.thumbsup.fill", "rosette", "sparkles"
            ]
        ),
        SFSymbolCategory(
            key: "applications",
            name: "Applications",
            icon: "app.badge",
            symbols: [
                "safari", "terminal", "folder.fill", "doc.fill",
                "envelope.fill", "message.fill", "phone.fill", "video.fill",
                "camera.fill", "music.note", "gamecontroller.fill", "book.fill"
            ]
        ),
        SFSymbolCategory(
            key: "media",
            name: "Media",
            icon: "playpause",
            symbols: [
                "play.fill", "pause.fill", "stop.fill", "forward.fill",
                "backward.fill", "speaker.wave.2.fill", "mic.fill", "photo.fill"
            ]
        )
    ]
}
