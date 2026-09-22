import Foundation

/// Ссылка так, как её вводят люди: `github.com`, `localhost:3000`, `mailto:…`. Без схемы `URL(string:)`
/// даёт «относительный» адрес, который `NSWorkspace.open` молча не открывает, — а в редакторе такая
/// ссылка выглядела настроенной (фавикон загружался). Здесь ей дописывается `https://`.
enum URLNormalizer {
    /// Ссылка, которую можно открыть; `nil` — пусто или не похоже на адрес.
    static func url(from raw: String) -> URL? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let candidate = hasScheme(text) ? text : "https://" + text
        if let url = URL(string: candidate) { return url }
        // Пробел или не-ASCII в пути: кодируем как есть, чтобы адрес с пробелом всё же открылся.
        guard let escaped = candidate.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: escaped)
    }

    /// Домен для подписи сектора и фавикона: без `www.`; `nil`, если это не веб-адрес.
    static func host(of raw: String) -> String? {
        guard let host = url(from: raw)?.host, !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// `https://…`, `mailto:…`, `x-apple.systempreferences:…` — схема есть. `localhost:3000` — нет:
    /// после двоеточия сразу порт.
    static func hasScheme(_ text: String) -> Bool {
        if text.contains("://") { return true }
        guard let colon = text.firstIndex(of: ":") else { return false }
        let scheme = text[..<colon]
        guard let first = scheme.first, first.isLetter,
              scheme.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." }) else {
            return false
        }
        let rest = text[text.index(after: colon)...]
        return !(rest.first?.isNumber ?? true)
    }
}
