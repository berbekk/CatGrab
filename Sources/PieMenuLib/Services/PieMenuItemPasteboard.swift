import AppKit
import Foundation

/// Обмен элементами меню между вкладками через системный буфер обмена.
enum PieMenuItemPasteboard {
    private static let type = NSPasteboard.PasteboardType("app.piemenu.pasteboard.menu-item-v1")

    static func copy(_ item: PieMenuItem) {
        guard let data = try? JSONEncoder().encode(item) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(data, forType: type)
    }

    static func read() -> PieMenuItem? {
        guard let data = NSPasteboard.general.data(forType: type) else { return nil }
        return try? JSONDecoder().decode(PieMenuItem.self, from: data)
    }

    /// Копия для вставки в другое меню: новый id и слот.
    static func itemForPasting(template: PieMenuItem, sectorIndex: Int) -> PieMenuItem {
        PieMenuItem(
            id: UUID(),
            title: template.title,
            icon: template.icon,
            action: template.action,
            color: template.color,
            iconColor: template.iconColor,
            sectorIndex: sectorIndex,
            customShortcut: template.customShortcut
        )
    }
}
