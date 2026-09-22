import CoreGraphics
import Foundation

/// Подпись сектора под курсором: что это и что произойдёт. У иконки приложения хватает и названия,
/// а у сочетания клавиш, ссылки или текста по значку не понять, что именно выполнится, —
/// поэтому вторая, приглушённая часть говорит это прямо.
struct PieHoverLabelText: Equatable {
    var title: String
    /// Ссылка, сочетание клавиш или начало текста; `nil` — довольно названия.
    var detail: String?

    /// Сколько символов текста показывать: подпись — одна строка снаружи кольца.
    static let detailLimit = 40

    init?(title: String, detail: String?) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = detail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasDetail = !(detail?.isEmpty ?? true)
        guard !title.isEmpty || hasDetail else { return nil }
        if title.isEmpty, let detail {
            self.title = detail
            self.detail = nil
        } else {
            self.title = title
            self.detail = hasDetail && detail != title ? detail : nil
        }
    }

    /// Первая непустая строка, не длиннее `detailLimit`, с многоточием.
    static func excerpt(_ text: String) -> String {
        let line = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        guard line.count > detailLimit else { return line }
        return String(line.prefix(detailLimit - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }
}

extension PieMenuItem {
    /// Подпись для кольца; `nil` — нечего сказать (пустой сектор без названия).
    func hoverLabel(language: AppLanguage) -> PieHoverLabelText? {
        switch action {
        case .unassigned:
            return PieHoverLabelText(title: title, detail: nil)
        case .launchApp:
            return PieHoverLabelText(title: title, detail: nil)
        case .openURL(let url):
            return PieHoverLabelText(title: title, detail: URLNormalizer.host(of: url) ?? PieHoverLabelText.excerpt(url))
        case .keystroke(let keyCode, let modifiers):
            let combo = HotkeyConfig.keystrokeGlyphString(keyCode: keyCode, modifiers: modifiers)
            return PieHoverLabelText(title: title, detail: combo)
        case .systemShortcut(let kind):
            return PieHoverLabelText(title: title.isEmpty ? kind.displayName(language: language) : title, detail: nil)
        case .snippet(let text):
            return PieHoverLabelText(title: title, detail: PieHoverLabelText.excerpt(text))
        }
    }
}

extension HotkeyConfig {
    /// Сочетание для подписи в кольце — значками, как в меню macOS: `⌘⇧N`, `⌃⌥→`.
    static func keystrokeGlyphString(keyCode: Int, modifiers: Int) -> String {
        guard keyCode != 0 || modifiers != 0 else { return "" }
        let flags = UInt64(modifiers)
        var result = ""
        if flags & CGEventFlags.maskSecondaryFn.rawValue != 0 { result += "fn " }
        if flags & CGEventFlags.maskControl.rawValue != 0 { result += "⌃" }
        if flags & CGEventFlags.maskAlternate.rawValue != 0 { result += "⌥" }
        if flags & CGEventFlags.maskShift.rawValue != 0 { result += "⇧" }
        if flags & CGEventFlags.maskCommand.rawValue != 0 { result += "⌘" }
        let glyphs: [Int: String] = [36: "↩", 48: "⇥", 49: "␣", 51: "⌫", 53: "⎋", 117: "⌦"]
        return result + (glyphs[keyCode] ?? keyCodeToString(keyCode))
    }
}
