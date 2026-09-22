import Foundation

/// Вид меню без содержимого: цвета, стекло, форма кольца, лапка, кот, цифры быстрого выбора
/// и тема, к которой вид привязан.
/// Так у набора команд одного приложения может быть свой вид поверх общего меню «Команды приложения».
/// Поворот сюда не входит — он у набора свой всегда (`AppSubMenu.rotationDegrees`).
struct MenuLook: Codable, Equatable {
    var colorScheme: SectorColorScheme
    var iconStyle: SectorIconStyle
    var menuRadius: Double
    var innerRadius: Double
    var iconDistance: Double
    var iconSize: Double
    var appearanceScale: Double
    var liquidGlass: LiquidGlassSettings
    var animationDuration: Double
    var pawDecorationEnabled: Bool
    var pawSizeScale: Double
    var pawRadialInset: Double
    var centerCatScale: Double
    var centerAppIconScale: Double
    var shortcutDigitSizeScale: Double
    var shortcutDigitInsetLeftScale: Double
    var shortcutDigitInsetRightScale: Double
    var shortcutDigitOpacity: Double
    var shortcutDigitColorHex: String
    /// Цвет кота в центре меню (и выглядывающего из-за иконки в меню команд), в HEX.
    var catColorHex: String
    /// Цвет лапки — и той, что хватает выбранный сектор, и той, что держит иконку в меню команд.
    var pawColorHex: String
    /// Подпись выделенного сектора снаружи кольца.
    var showsHoverLabel: Bool
    /// Своя тема, которой оформлено меню; `nil` — оформление не из темы.
    var themeID: UUID?

    init(_ menu: PieMenu) {
        colorScheme = menu.colorScheme
        iconStyle = menu.iconStyle
        menuRadius = menu.menuRadius
        innerRadius = menu.innerRadius
        iconDistance = menu.iconDistance
        iconSize = menu.iconSize
        appearanceScale = menu.appearanceScale
        liquidGlass = menu.liquidGlass
        animationDuration = menu.animationDuration
        pawDecorationEnabled = menu.pawDecorationEnabled
        pawSizeScale = menu.pawSizeScale
        pawRadialInset = menu.pawRadialInset
        centerCatScale = menu.centerCatScale
        centerAppIconScale = menu.centerAppIconScale
        shortcutDigitSizeScale = menu.shortcutDigitSizeScale
        shortcutDigitInsetLeftScale = menu.shortcutDigitInsetLeftScale
        shortcutDigitInsetRightScale = menu.shortcutDigitInsetRightScale
        shortcutDigitOpacity = menu.shortcutDigitOpacity
        shortcutDigitColorHex = menu.shortcutDigitColorHex
        catColorHex = menu.catColorHex
        pawColorHex = menu.pawColorHex
        showsHoverLabel = menu.showsHoverLabel
        themeID = menu.themeID
    }

    private enum CodingKeys: String, CodingKey {
        case colorScheme, iconStyle, menuRadius, innerRadius, iconDistance, iconSize, appearanceScale
        case liquidGlass, animationDuration, pawDecorationEnabled, pawSizeScale, pawRadialInset
        case centerCatScale, centerAppIconScale, shortcutDigitSizeScale, shortcutDigitInsetLeftScale
        case shortcutDigitInsetRightScale, shortcutDigitOpacity, shortcutDigitColorHex
        case catColorHex, pawColorHex, showsHoverLabel, themeID
    }

    /// Тема, сохранённая до появления цвета кота и лапки, — они получают исходный чёрный.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        colorScheme = try container.decode(SectorColorScheme.self, forKey: .colorScheme)
        iconStyle = try container.decode(SectorIconStyle.self, forKey: .iconStyle)
        menuRadius = try container.decode(Double.self, forKey: .menuRadius)
        innerRadius = try container.decode(Double.self, forKey: .innerRadius)
        iconDistance = try container.decode(Double.self, forKey: .iconDistance)
        iconSize = try container.decode(Double.self, forKey: .iconSize)
        appearanceScale = try container.decode(Double.self, forKey: .appearanceScale)
        liquidGlass = try container.decode(LiquidGlassSettings.self, forKey: .liquidGlass)
        animationDuration = try container.decode(Double.self, forKey: .animationDuration)
        pawDecorationEnabled = try container.decode(Bool.self, forKey: .pawDecorationEnabled)
        pawSizeScale = try container.decode(Double.self, forKey: .pawSizeScale)
        pawRadialInset = try container.decode(Double.self, forKey: .pawRadialInset)
        centerCatScale = try container.decode(Double.self, forKey: .centerCatScale)
        centerAppIconScale = try container.decode(Double.self, forKey: .centerAppIconScale)
        shortcutDigitSizeScale = try container.decode(Double.self, forKey: .shortcutDigitSizeScale)
        shortcutDigitInsetLeftScale = try container.decode(Double.self, forKey: .shortcutDigitInsetLeftScale)
        shortcutDigitInsetRightScale = try container.decode(Double.self, forKey: .shortcutDigitInsetRightScale)
        shortcutDigitOpacity = try container.decode(Double.self, forKey: .shortcutDigitOpacity)
        shortcutDigitColorHex = try container.decode(String.self, forKey: .shortcutDigitColorHex)
        catColorHex = try container.decodeIfPresent(String.self, forKey: .catColorHex) ?? PieMenu.defaultCatColorHex
        pawColorHex = try container.decodeIfPresent(String.self, forKey: .pawColorHex) ?? PieMenu.defaultPawColorHex
        showsHoverLabel = try container.decodeIfPresent(Bool.self, forKey: .showsHoverLabel) ?? true
        themeID = try container.decodeIfPresent(UUID.self, forKey: .themeID)
    }

    /// Переносит вид на меню; имя, хоткей, пункты, команды и поворот остаются как были.
    func apply(to menu: inout PieMenu) {
        menu.colorScheme = colorScheme
        menu.iconStyle = iconStyle
        menu.menuRadius = menuRadius
        menu.innerRadius = PieMenu.clampedInnerRadius(innerRadius, outerRadius: menuRadius)
        menu.iconDistance = iconDistance
        menu.iconSize = iconSize
        menu.appearanceScale = PieMenu.clampedAppearanceScale(appearanceScale)
        menu.liquidGlass = liquidGlass
        menu.animationDuration = animationDuration
        menu.pawDecorationEnabled = pawDecorationEnabled
        menu.pawSizeScale = PieMenu.clampedPawSizeScale(pawSizeScale)
        menu.pawRadialInset = PieMenu.clampedPawRadialInset(pawRadialInset)
        menu.centerCatScale = PieMenu.clampedCenterCatScale(centerCatScale)
        menu.centerAppIconScale = PieMenu.clampedCenterAppIconScale(centerAppIconScale)
        menu.shortcutDigitSizeScale = PieMenu.clampedShortcutDigitSizeScale(shortcutDigitSizeScale)
        menu.shortcutDigitInsetLeftScale = PieMenu.clampedShortcutDigitInsetLeftScale(shortcutDigitInsetLeftScale)
        menu.shortcutDigitInsetRightScale = PieMenu.clampedShortcutDigitInsetRightScale(shortcutDigitInsetRightScale)
        menu.shortcutDigitOpacity = PieMenu.clampedShortcutDigitOpacity(shortcutDigitOpacity)
        menu.shortcutDigitColorHex = shortcutDigitColorHex
        menu.catColorHex = catColorHex
        menu.pawColorHex = pawColorHex
        menu.showsHoverLabel = showsHoverLabel
        menu.themeID = themeID
    }
}
