import CryptoKit
import Foundation

/// Команды активного приложения в виде пунктов кольца — для меню «Команды приложения».
enum AppCommandsMenuItems {
    /// Иконки команд белые: цвет сектора уже различает соседей, а белый значок читается на любом из них.
    static let iconColorHex = "#FFFFFF"

    /// Пункт для каждой команды, в том же порядке. Цвета секторов — из общей палитры, как у остальных меню,
    /// а «Завершить» — предупреждающий красный, чтобы его не спутать с безобидными соседями.
    static func build(actions: [PieSubAction], bundleIdentifier: String) -> [PieMenuItem] {
        actions.enumerated().map { index, action in
            PieMenuItem(
                id: stableID("\(bundleIdentifier)|\(index)|\(action.id)"),
                title: action.title,
                icon: action.icon,
                action: .unassigned,
                color: sectorColor(index: index, isDestructive: action.isDestructive),
                iconColor: iconColorHex,
                sectorIndex: index
            )
        }
    }

    /// Превью в настройках — набор по умолчанию. Настоящие команды зависят от того, какое приложение
    /// активно в момент вызова, а в настройках активен сам CatGrab. id сектора — id команды: так
    /// перетаскивание в превью находит, что переставлять.
    static func previewItems(entries: [AppSubMenuEntry]) -> [PieMenuItem] {
        entries.enumerated().map { index, entry in
            PieMenuItem(
                id: entry.id,
                title: entry.kind.rawValue,
                icon: entry.resolvedIcon,
                action: .openURL(url: ""),
                color: sectorColor(index: index, isDestructive: entry.kind == .quitApp),
                iconColor: iconColorHex,
                sectorIndex: index
            )
        }
    }

    private static func sectorColor(index: Int, isDestructive: Bool) -> String {
        isDestructive ? DS.Pie.destructiveSubSectorTintHex : PieMenuItem.paletteColor(for: index)
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
