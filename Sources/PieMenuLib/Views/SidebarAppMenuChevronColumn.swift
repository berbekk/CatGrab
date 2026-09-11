import SwiftUI

/// Правая колонка как у `HotkeyRecorderView`: `HStack` + `Spacer` + контрол, те же отступы и высота `fieldHeight`, ширина `sidebarHotkeyColumnMaxWidth`.
struct SidebarAppMenuChevronColumn: View {
    var action: () -> Void
    var helpText: String
    /// Число меню для приложения; `nil` — без подписи.
    var menuCount: Int? = nil

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: DS.Spacing.xs) {
                if let menuCount {
                    Text("\(menuCount)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary.opacity(0.75))
                        .monospacedDigit()
                }
                Button(action: action) {
                    SidebarAppMenuPickerChevronLabel(appSidebarRow: true)
                }
                .buttonStyle(.borderless)
                .pointingHandCursor()
                .help(helpText)
            }
        }
        .padding(.leading, DS.Spacing.fieldInsetHorizontal)
        .padding(.trailing, DS.Sizing.sidebarAppMenuChevronColumnPaddingTrailing)
        .frame(height: DS.Sizing.fieldHeight)
        .frame(width: DS.Sizing.sidebarHotkeyColumnMaxWidth, alignment: .trailing)
    }
}
