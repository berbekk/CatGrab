import Foundation

enum LiquidGlassVariant: String, Codable, CaseIterable {
    case regular
    case clear
}

struct LiquidGlassSettings: Codable, Equatable {
    var variant: LiquidGlassVariant
    var tintOpacity: Double

    static let `default` = LiquidGlassSettings(
        variant: .regular,
        tintOpacity: 0.07
    )

    private enum CodingKeys: String, CodingKey {
        case variant
        case tintOpacity
    }

    init(
        variant: LiquidGlassVariant = .regular,
        tintOpacity: Double = 0.07
    ) {
        self.variant = variant
        self.tintOpacity = tintOpacity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        variant = try container.decodeIfPresent(LiquidGlassVariant.self, forKey: .variant) ?? .regular
        tintOpacity = try container.decodeIfPresent(Double.self, forKey: .tintOpacity) ?? 0.07
    }
}
