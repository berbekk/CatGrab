import Foundation

// MARK: - Color scheme

/// Как раскрашено кольцо. Сектор, у которого нет своего цвета (`PieMenuItem.usesThemeColor`), берёт
/// цвет по своему месту в кольце — поэтому градиент идёт ровно при любом числе секторов, а новый
/// сектор сразу в теме.
struct SectorColorScheme: Codable, Equatable {
    enum Mode: String, Codable, CaseIterable, Identifiable {
        /// Цвета по кругу, повторяются, если секторов больше.
        case palette
        /// Плавный переход через опорные цвета — от первого сектора к последнему.
        case gradient
        /// Все секторы одного цвета.
        case single

        var id: String { rawValue }
    }

    var mode: Mode
    var colors: [String]
    /// Готовая тема, из которой взята схема; `nil` — своя (цвета меняли вручную).
    var presetID: String?

    /// Больше цветов, чем секторов в разумном меню, палитре не нужно.
    static let maxPaletteColors = 12
    static let maxGradientStops = 5

    func color(at index: Int, count: Int) -> String {
        guard !colors.isEmpty else { return PieMenuItem.paletteColor(for: index) }
        switch mode {
        case .palette:
            return colors[((index % colors.count) + colors.count) % colors.count]
        case .single:
            return colors[0]
        case .gradient:
            guard colors.count > 1, count > 1 else { return colors[0] }
            let t = Double(min(max(index, 0), count - 1)) / Double(count - 1)
            return HexColor.interpolate(colors, at: t)
        }
    }

    /// Цвета, которые предлагают сектору «под тему»: палитра как есть, у градиента — пять шагов.
    var sampleColors: [String] {
        switch mode {
        case .palette, .single: return colors
        case .gradient: return (0..<5).map { color(at: $0, count: 5) }
        }
    }

    /// Смена режима сохраняет характер цветов: палитра становится градиентом от первого цвета к последнему,
    /// один цвет раскладывается в соседние оттенки.
    mutating func switchMode(to newMode: Mode) {
        guard newMode != mode, let first = colors.first else { return }
        switch (mode, newMode) {
        case (_, .single):
            colors = [first]
        case (.palette, .gradient):
            colors = [first, colors.last ?? first]
        case (.gradient, .palette):
            colors = (0..<6).map { color(at: $0, count: 6) }
        case (.single, .palette):
            colors = (0..<6).map { HexColor.rotateHue(first, by: Double($0) * 30) }
        case (.single, .gradient):
            colors = [first, HexColor.rotateHue(first, by: 60)]
        default:
            break
        }
        mode = newMode
        presetID = nil
    }
}

/// Цвет иконок-символов в секторах. Иконки приложений и эмодзи остаются как есть.
enum SectorIconStyle: String, Codable, CaseIterable, Identifiable {
    /// В цвет своего сектора.
    case tinted
    /// Белые — читаются на любой насыщенной заливке.
    case white

    var id: String { rawValue }
}

// MARK: - Presets

/// Готовая тема: схема раскраски плюс насыщенность, вид стекла и цвет иконок, которые ей идут.
struct MenuThemePreset: Identifiable, Equatable {
    let id: String
    let scheme: SectorColorScheme
    let intensity: Double
    let glass: LiquidGlassVariant
    let icons: SectorIconStyle

    private init(
        _ id: String,
        _ mode: SectorColorScheme.Mode,
        _ colors: [String],
        intensity: Double,
        glass: LiquidGlassVariant = .regular,
        icons: SectorIconStyle = .white
    ) {
        self.id = id
        self.scheme = SectorColorScheme(mode: mode, colors: colors, presetID: id)
        self.intensity = intensity
        self.glass = glass
        self.icons = icons
    }

    static let classic = MenuThemePreset("classic", .palette, PieMenuItem.sectorPalette, intensity: 0.3, icons: .tinted)

    /// Галерея — сетка 4 × 6, каждый ряд — своя группа: спокойные, яркие, смелые, пастельные,
    /// холодные градиенты, природные. Соседние темы заметно отличаются — перебирать есть что.
    static let all: [MenuThemePreset] = [
        classic,
        MenuThemePreset("crystal", .single, ["#FFFFFF"], intensity: 0.06, glass: .clear),
        MenuThemePreset("mono", .palette, ["#8E8E93", "#AEAEB2", "#636366", "#C7C7CC", "#7C7C80", "#A3A3A8", "#545458", "#B8B8BD"], intensity: 0.35),
        MenuThemePreset("graphite", .single, ["#8E8E93"], intensity: 0.3),

        MenuThemePreset("rainbow", .palette, ["#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE", "#007AFF", "#5856D6", "#AF52DE"], intensity: 0.4),
        MenuThemePreset("retro", .palette, ["#F94144", "#F3722C", "#F8961E", "#F9C74F", "#90BE6D", "#43AA8B", "#577590"], intensity: 0.45),
        MenuThemePreset("candy", .palette, ["#FF2D55", "#FF9500", "#FFCC00", "#FF6482", "#FF375F", "#FFB340"], intensity: 0.45),
        MenuThemePreset("citrus", .palette, ["#FFD60A", "#FF9F0A", "#A8E063", "#FFB703", "#C1FF72", "#FB8500"], intensity: 0.45),

        MenuThemePreset("neon", .palette, ["#00F5D4", "#00BBF9", "#9B5DE5", "#F15BB5", "#FEE440", "#39FF14"], intensity: 0.5),
        MenuThemePreset("cyber", .palette, ["#FF00A0", "#00F0FF", "#FFE600", "#7000FF"], intensity: 0.5),
        MenuThemePreset("berry", .gradient, ["#FF4E8A", "#7B2FF7"], intensity: 0.45),
        MenuThemePreset("sunset", .gradient, ["#F72585", "#FF7B00", "#FFD000"], intensity: 0.45),

        MenuThemePreset("pastel", .palette, ["#A0C4FF", "#BDB2FF", "#FFC6FF", "#FFADAD", "#FFD6A5", "#FDFFB6", "#CAFFBF", "#9BF6FF"], intensity: 0.45),
        MenuThemePreset("sakura", .palette, ["#FFB7C5", "#FF8FAB", "#FFC2D1", "#FB6F92", "#FFE5EC", "#F4ACB7"], intensity: 0.45),
        MenuThemePreset("lavender", .gradient, ["#D8B4FE", "#818CF8"], intensity: 0.45),
        MenuThemePreset("mint", .gradient, ["#A7F3D0", "#2DD4BF"], intensity: 0.4),

        MenuThemePreset("ice", .gradient, ["#E0F2FE", "#60A5FA"], intensity: 0.35, glass: .clear),
        MenuThemePreset("ocean", .gradient, ["#48CAE4", "#0077B6", "#03045E"], intensity: 0.5),
        MenuThemePreset("aurora", .gradient, ["#00F5A0", "#00D9F5", "#7B61FF"], intensity: 0.45),
        MenuThemePreset("midnight", .gradient, ["#1A1A6E", "#4361EE"], intensity: 0.55),

        MenuThemePreset("forest", .palette, ["#1B4332", "#2D6A4F", "#40916C", "#52B788", "#74C69D", "#95D5B2"], intensity: 0.5),
        MenuThemePreset("autumn", .palette, ["#9C6644", "#BC6C25", "#DDA15E", "#E9C46A", "#D4A373", "#8D5524"], intensity: 0.45),
        MenuThemePreset("gold", .gradient, ["#8C6A1E", "#F5D061"], intensity: 0.45),
        MenuThemePreset("coffee", .palette, ["#5C4033", "#6F4E37", "#8B5A2B", "#A67B5B", "#C8A27A", "#D2B48C"], intensity: 0.5)
    ]

    static func withID(_ id: String?) -> MenuThemePreset? {
        all.first { $0.id == id }
    }
}

// MARK: - Swatch library

/// Своя тема — стиль меню целиком: цвет, форма и детали (`MenuLook`), плюс имя. Меню привязывается
/// к теме (`PieMenu.themeID`): сохранённые изменения темы расходятся по всем её меню, а правки
/// в одном меню до сохранения видны как «тема изменена» — их можно сохранить или откатить.
/// Готовые палитры (`MenuThemePreset`) — не темы: они лишь меняют цвета текущей темы.
struct CustomMenuTheme: Codable, Equatable, Identifiable {
    /// Первая версия тем помечала раскраску меню как `custom:<id>` — нужно для переноса привязки.
    static let legacyIDPrefix = "custom:"

    var id: UUID
    var name: String
    var look: MenuLook

    /// Тема из того, как сейчас выглядит меню.
    init(id: UUID = UUID(), name: String, menu: PieMenu) {
        self.id = id
        self.name = name
        look = Self.normalized(MenuLook(menu))
    }

    /// Меню выглядит ровно как тема: правок, которые не сохранены в тему, нет. Размер иконки
    /// приложения в центре меню команд и метка палитры в сравнение не входят.
    func matches(_ menu: PieMenu) -> Bool {
        var current = Self.normalized(MenuLook(menu))
        current.centerAppIconScale = look.centerAppIconScale
        current.colorScheme.presetID = look.colorScheme.presetID
        return current == look
    }

    /// Переснять тему с меню: имя и место в списке остаются.
    mutating func update(from menu: PieMenu) {
        look = Self.normalized(MenuLook(menu))
    }

    /// Вид темы сам ни к какой теме не привязан.
    private static func normalized(_ look: MenuLook) -> MenuLook {
        var look = look
        look.themeID = nil
        if look.colorScheme.presetID?.hasPrefix(legacyIDPrefix) == true {
            look.colorScheme.presetID = nil
        }
        return look
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, look
        case scheme, intensity, glass, icons // первая версия своих тем: только цвета
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        if let look = try container.decodeIfPresent(MenuLook.self, forKey: .look) {
            self.look = Self.normalized(look)
        } else {
            // Тема только из цветов: форма и детали — как у нового меню.
            var menu = PieMenu(name: name)
            menu.colorScheme = try container.decode(SectorColorScheme.self, forKey: .scheme)
            menu.liquidGlass.tintOpacity = try container.decode(Double.self, forKey: .intensity)
            menu.liquidGlass.variant = try container.decode(LiquidGlassVariant.self, forKey: .glass)
            menu.iconStyle = try container.decode(SectorIconStyle.self, forKey: .icons)
            look = Self.normalized(MenuLook(menu))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(look, forKey: .look)
    }
}

extension PieMenu {
    /// Оформить меню темой и привязать к ней. Поворот остаётся свой — он зависит от числа секторов,
    /// как и размер иконки приложения в центре меню команд.
    mutating func applyTheme(_ theme: CustomMenuTheme) {
        let centerAppIconScale = centerAppIconScale
        theme.look.apply(to: &self)
        self.centerAppIconScale = centerAppIconScale
        themeID = theme.id
    }

    func theme(in themes: [CustomMenuTheme]) -> CustomMenuTheme? {
        themeID.flatMap { id in themes.first { $0.id == id } }
    }

    /// Меню привязано к теме, но выглядит иначе: есть правки, не сохранённые в тему.
    func hasUnsavedThemeChanges(in themes: [CustomMenuTheme]) -> Bool {
        theme(in: themes).map { !$0.matches(self) } ?? false
    }
}

/// Тема, которая не читается (из будущей версии), пропускается, а не роняет весь конфиг.
struct LossyCustomMenuTheme: Decodable {
    let theme: CustomMenuTheme?

    init(from decoder: Decoder) throws {
        theme = try? CustomMenuTheme(from: decoder)
    }
}

/// Цвета для выбора вручную: 12 оттенков по кругу × 6 тонов (от почти белого к глубокому) и строка серых.
/// Столбцы — оттенки, строки — тона, как в палитрах графических редакторов.
enum ColorSwatchLibrary {
    static let columns = 12

    static let all: [String] = {
        let hues: [Double] = [0, 24, 38, 52, 80, 135, 165, 190, 212, 240, 275, 330]
        let tones: [(saturation: Double, brightness: Double)] = [
            (0.14, 1), (0.32, 1), (0.6, 1), (0.85, 0.95), (0.9, 0.72), (0.9, 0.48)
        ]
        let grays: [Double] = [1, 0.92, 0.84, 0.74, 0.64, 0.55, 0.46, 0.38, 0.3, 0.22, 0.14, 0.06]
        var colors = tones.flatMap { tone in hues.map { HexColor.fromHSB($0 / 360, tone.saturation, tone.brightness) } }
        colors += grays.map { HexColor.fromHSB(0, 0, $0) }
        return colors
    }()
}

// MARK: - Hex math

/// Арифметика над `#RRGGBB` без AppKit: модель должна считать цвета и в тестах.
enum HexColor {
    static func rgb(_ hex: String) -> (r: Double, g: Double, b: Double)? {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        return (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    static func hex(_ r: Double, _ g: Double, _ b: Double) -> String {
        func byte(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
    }

    static func isValid(_ hex: String) -> Bool { rgb(hex) != nil }

    /// Цвета почти совпадают — на глаз не отличить (запас на пересчёт цветовых пространств).
    static func isClose(_ a: String, _ b: String, tolerance: Double = 14.0 / 255) -> Bool {
        guard let x = rgb(a), let y = rgb(b) else { return false }
        return abs(x.r - y.r) <= tolerance && abs(x.g - y.g) <= tolerance && abs(x.b - y.b) <= tolerance
    }

    /// Точка на ломаной через опорные цвета, `t` от 0 до 1.
    static func interpolate(_ stops: [String], at t: Double) -> String {
        let points = stops.compactMap(rgb)
        guard let first = points.first else { return stops.first ?? "#FFFFFF" }
        guard points.count > 1 else { return hex(first.r, first.g, first.b) }
        let scaled = min(max(t, 0), 1) * Double(points.count - 1)
        let i = min(Int(scaled), points.count - 2)
        let f = scaled - Double(i)
        let a = points[i], b = points[i + 1]
        return hex(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f)
    }

    static func fromHSB(_ h: Double, _ s: Double, _ v: Double) -> String {
        let hue = (h.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * 6
        let c = v * s, x = c * (1 - abs(hue.truncatingRemainder(dividingBy: 2) - 1)), m = v - c
        let (r, g, b): (Double, Double, Double)
        switch Int(hue) {
        case 0: (r, g, b) = (c, x, 0)
        case 1: (r, g, b) = (x, c, 0)
        case 2: (r, g, b) = (0, c, x)
        case 3: (r, g, b) = (0, x, c)
        case 4: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return hex(r + m, g + m, b + m)
    }

    static func toHSB(_ hexValue: String) -> (h: Double, s: Double, b: Double)? {
        guard let (r, g, b) = rgb(hexValue) else { return nil }
        let maxV = max(r, g, b), minV = min(r, g, b), delta = maxV - minV
        var h = 0.0
        if delta > 0 {
            if maxV == r { h = ((g - b) / delta).truncatingRemainder(dividingBy: 6) } else if maxV == g { h = (b - r) / delta + 2 } else { h = (r - g) / delta + 4 }
            h /= 6
            if h < 0 { h += 1 }
        }
        return (h, maxV == 0 ? 0 : delta / maxV, maxV)
    }

    static func rotateHue(_ hexValue: String, by degrees: Double) -> String {
        guard let hsb = toHSB(hexValue) else { return hexValue }
        return fromHSB(hsb.h + degrees / 360, hsb.s, hsb.b)
    }
}

// MARK: - App appearance

/// Оформление окон приложения. Само кольцо всегда тёмное — стекло задумано на тёмном.
enum AppAppearance: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
}
