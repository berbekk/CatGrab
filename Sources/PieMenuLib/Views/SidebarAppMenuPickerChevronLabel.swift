import SwiftUI

/// В хоткее — `chevron.up.chevron.down`; в строке приложения сайдбара — `chevron.down` (выбор из меню).
struct SidebarAppMenuPickerChevronLabel: View {
    /// `true` только у выбора приложения в сайдбаре: больше глиф, шире зона нажатия.
    var appSidebarRow = false

    var body: some View {
        Image(systemName: appSidebarRow ? "chevron.down" : "chevron.up.chevron.down")
            .font(appSidebarRow ? DS.Typography.control : DS.Typography.label)
            .foregroundStyle(appSidebarRow ? Color.secondary.opacity(0.92) : DS.Colors.hotkeyLabel)
            .frame(
                width: appSidebarRow ? 30 : 24,
                height: appSidebarRow ? DS.Sizing.fieldHeight - 2 : DS.Sizing.fieldHeight - 6,
                alignment: .center
            )
            .contentShape(Rectangle())
    }
}
