import Foundation

enum LiquidGlassVariant: String, Codable, CaseIterable {
    case regular
    case clear
    /// Без стекла: сплошная заливка с чёткой обводкой, рабочий стол сквозь кольцо не виден.
    case solid
}

struct LiquidGlassSettings: Codable, Equatable {
    var variant: LiquidGlassVariant
    var tintOpacity: Double
    /// Светлое или тёмное кольцо; меню, сохранённые до выбора, остаются тёмными.
    var appearance: RingAppearance

    /// Насыщенность как у палитры «Классика»: при 0.07 цвета секторов почти не читались, и новое
    /// кольцо выглядело серым, пока пользователь не находил ползунок.
    static let defaultTintOpacity = 0.3

    static let `default` = LiquidGlassSettings(
        variant: .regular,
        tintOpacity: defaultTintOpacity
    )

    var isSolid: Bool { variant == .solid }

    private enum CodingKeys: String, CodingKey {
        case variant
        case tintOpacity
        case appearance
    }

    init(
        variant: LiquidGlassVariant = .regular,
        tintOpacity: Double = LiquidGlassSettings.defaultTintOpacity,
        appearance: RingAppearance = .dark
    ) {
        self.variant = variant
        self.tintOpacity = tintOpacity
        self.appearance = appearance
    }

    /// Незнакомое значение (из более новой версии) не роняет меню: берётся вид по умолчанию.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        variant = (try? container.decodeIfPresent(LiquidGlassVariant.self, forKey: .variant)) ?? .regular
        tintOpacity = try container.decodeIfPresent(Double.self, forKey: .tintOpacity) ?? Self.defaultTintOpacity
        appearance = (try? container.decodeIfPresent(RingAppearance.self, forKey: .appearance)) ?? .dark
    }
}
