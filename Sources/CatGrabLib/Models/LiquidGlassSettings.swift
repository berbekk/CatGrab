import Foundation

enum LiquidGlassVariant: String, Codable, CaseIterable {
    case regular
    case clear
}

struct LiquidGlassSettings: Codable, Equatable {
    var variant: LiquidGlassVariant
    var tintOpacity: Double

    /// Насыщенность как у палитры «Классика»: при 0.07 цвета секторов почти не читались, и новое
    /// кольцо выглядело серым, пока пользователь не находил ползунок.
    static let defaultTintOpacity = 0.3

    static let `default` = LiquidGlassSettings(
        variant: .regular,
        tintOpacity: defaultTintOpacity
    )

    private enum CodingKeys: String, CodingKey {
        case variant
        case tintOpacity
    }

    init(
        variant: LiquidGlassVariant = .regular,
        tintOpacity: Double = LiquidGlassSettings.defaultTintOpacity
    ) {
        self.variant = variant
        self.tintOpacity = tintOpacity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        variant = try container.decodeIfPresent(LiquidGlassVariant.self, forKey: .variant) ?? .regular
        tintOpacity = try container.decodeIfPresent(Double.self, forKey: .tintOpacity) ?? Self.defaultTintOpacity
    }
}
