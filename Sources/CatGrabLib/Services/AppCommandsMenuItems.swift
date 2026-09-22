import CryptoKit
import Foundation

/// Команды активного приложения в виде пунктов кольца — для меню «Команды приложения».
enum AppCommandsMenuItems {
    /// Пункт для каждой команды, в том же порядке. Команды разрешаются из набора один к одному
    /// (недоступные остаются на месте приглушёнными), поэтому цвета и клавиша берутся у команды
    /// набора с тем же номером.
    static func build(
        actions: [PieSubAction],
        entries: [AppSubMenuEntry],
        bundleIdentifier: String
    ) -> [PieMenuItem] {
        actions.enumerated().map { index, action in
            item(
                id: stableID("\(bundleIdentifier)|\(index)|\(action.id)"),
                title: action.title,
                icon: action.icon,
                entry: index < entries.count ? entries[index] : nil,
                index: index,
                action: sectorAction(for: index < entries.count ? entries[index] : nil)
            )
        }
    }

    /// Превью в настройках. Настоящие команды зависят от того, какое приложение активно в момент
    /// вызова, а в настройках активен сам CatGrab. id сектора — id команды: так выбор и перетаскивание
    /// в превью находят, что менять.
    static func previewItems(entries: [AppSubMenuEntry]) -> [PieMenuItem] {
        entries.enumerated().map { index, entry in
            item(
                id: entry.id,
                title: entry.kind.rawValue,
                icon: entry.resolvedIcon,
                entry: entry,
                index: index,
                action: entry.kind == .action ? sectorAction(for: entry) : .openURL(url: "")
            )
        }
    }

    /// Сектор без своего цвета берёт цвет темы по месту (`PieMenu.themed`), как пункт обычного меню.
    private static func item(
        id: UUID,
        title: String,
        icon: String,
        entry: AppSubMenuEntry?,
        index: Int,
        action: MenuAction
    ) -> PieMenuItem {
        let ownColor = entry?.color
        return PieMenuItem(
            id: id,
            title: title,
            icon: icon,
            action: action,
            color: ownColor ?? PieMenuItem.paletteColor(for: index),
            usesThemeColor: ownColor == nil,
            iconColor: entry?.iconColor,
            sectorIndex: index,
            customShortcut: entry?.customShortcut
        )
    }

    /// Выполняется сектор через команды (`PieSubAction`), а действие у пункта — чтобы кольцо нарисовало
    /// иконку приложения у сектора «Открыть приложение», как в обычном меню.
    private static func sectorAction(for entry: AppSubMenuEntry?) -> MenuAction {
        guard let entry, entry.kind == .action else { return .unassigned }
        return entry.action ?? .unassigned
    }

    /// Стабильный id: SwiftUI не должен пересоздавать секторы при каждом показе.
    private static func stableID(_ key: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(key.utf8)).prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
