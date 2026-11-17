import Foundation

/// Светлое или тёмное кольцо. Стекло и подложку без стекла система рисует по-разному в светлом
/// и тёмном оформлении, поэтому сторону выбирают явно, а не по фону под кольцом.
enum RingAppearance: String, Codable, CaseIterable, Identifiable {
    case dark
    case light
    /// Как оформление macOS в момент показа.
    case system

    var id: String { rawValue }

    func isDark(systemIsDark: Bool) -> Bool {
        switch self {
        case .dark: return true
        case .light: return false
        case .system: return systemIsDark
        }
    }
}

/// Цвета кольца для одной стороны (светлое или тёмное) и материала (стекло или без стекла).
///
/// Цвета темы подобраны на тёмном кольце: белые значки и цифры на светлом кольце пропадают, а
/// тёмно-синие — на тёмном. Палитра прикидывает, каким выйдет сектор (подложка плюс цвет темы с его
/// насыщенностью), и подправляет цвет значков и цифр, пока он не станет читаться. Своих цветов
/// пользователь не теряет: в конфиге остаётся то, что он выбрал, правка — только при отрисовке.
struct RingPalette: Equatable {
    let isDark: Bool
    let isSolid: Bool

    /// Порог контраста по WCAG для крупных значков и нетекстовых элементов.
    static let minimumContrast = 3.0
    /// Почти чёрный, которым становятся белые значки и цифры на светлом кольце.
    static let darkInkHex = "#1D1D1F"
    static let lightInkHex = "#FFFFFF"

    init(isDark: Bool, isSolid: Bool) {
        self.isDark = isDark
        self.isSolid = isSolid
    }

    init(settings: LiquidGlassSettings, systemIsDark: Bool) {
        self.init(
            isDark: settings.appearance.isDark(systemIsDark: systemIsDark),
            isSolid: settings.variant == .solid
        )
    }

    /// Сектор без цвета темы. У стекла — примерный цвет на обычном рабочем столе: точнее не узнать,
    /// стекло зависит от того, что под ним.
    var baseHex: String {
        switch (isSolid, isDark) {
        case (true, true): return "#1C1C1F"
        case (true, false): return "#FFFFFF"
        case (false, true): return "#2C2C30"
        case (false, false): return "#ECECEF"
        }
    }

    /// Каким примерно выйдет сектор с цветом темы `tintHex` при насыщенности `alpha`.
    func sectorHex(tint tintHex: String, alpha: Double) -> String {
        HexColor.mix(baseHex, tintHex, amount: min(1, max(0, alpha)))
    }

    /// Цвет значка или цифры, который читается на секторе `backgroundHex`. Если исходный читается —
    /// он и остаётся. Серые и белые становятся чернилами нужной стороны, цветные сохраняют оттенок
    /// и темнеют (или светлеют) ровно настолько, насколько нужно.
    func readable(_ hex: String, on backgroundHex: String) -> String {
        Self.readable(hex, on: backgroundHex)
    }

    static func readable(_ hex: String, on backgroundHex: String, minimum: Double = minimumContrast) -> String {
        guard HexColor.isValid(hex), HexColor.isValid(backgroundHex) else { return hex }
        if HexColor.contrastRatio(hex, backgroundHex) >= minimum { return hex }
        // Светлее этой яркости фон контрастнее с чёрным, чем с белым.
        let darken = HexColor.relativeLuminance(backgroundHex) > 0.179
        let saturation = HexColor.toHSB(hex)?.s ?? 0
        if saturation < 0.2 {
            return darken ? darkInkHex : lightInkHex
        }
        let target = darken ? "#000000" : "#FFFFFF"
        var amount = 0.0
        var candidate = hex
        while amount < 1 {
            amount = min(1, amount + 0.05)
            candidate = HexColor.mix(hex, target, amount: amount)
            if HexColor.contrastRatio(candidate, backgroundHex) >= minimum { break }
        }
        return candidate
    }
}

extension HexColor {
    /// Смесь двух цветов: `amount` 0 — первый, 1 — второй.
    static func mix(_ a: String, _ b: String, amount: Double) -> String {
        guard let x = rgb(a) else { return b }
        guard let y = rgb(b) else { return a }
        let t = min(1, max(0, amount))
        return hex(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t)
    }

    /// Относительная яркость по WCAG (0 — чёрный, 1 — белый).
    static func relativeLuminance(_ hexValue: String) -> Double {
        guard let (r, g, b) = rgb(hexValue) else { return 0 }
        func linear(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    /// Контраст двух цветов по WCAG: от 1 (одинаковые) до 21 (чёрный и белый).
    static func contrastRatio(_ a: String, _ b: String) -> Double {
        let la = relativeLuminance(a), lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
