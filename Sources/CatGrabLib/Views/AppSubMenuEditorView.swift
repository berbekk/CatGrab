import AppKit
import SwiftUI

/// Свой набор команд одного приложения — правая панель настроек, когда в сайдбаре выбрано приложение.
/// Настраивается так же, как любое меню: превью, инспектор сектора, список команд и панель «Параметры».
struct AppSubMenuEditorView: View {
    let bundleIdentifier: String
    /// Меню команд этого приложения (`PieConfiguration.appSetMenu`): вид, поворот и команды набора.
    @Binding var menu: PieMenu
    var hapticFeedbackEnabled: Bool
    @Binding var showAppearancePanel: Bool
    /// Свои темы — чтобы «Оформление» назвало тему меню.
    var customThemes: [CustomMenuTheme] = []
    /// Убрать свой набор — приложение снова получит автоматические команды.
    var onReset: () -> Void

    @EnvironmentObject private var localizer: LocalizationStore

    static func appName(for bundleIdentifier: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundleIdentifier
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                header
                SettingsCard {
                    SettingsRow(localizer.text(.appearanceRowTitle)) {
                        MenuStyleField(
                            menu: menu,
                            customThemes: customThemes,
                            isActive: showAppearancePanel,
                            onQuickApply: { menu.applyTheme($0) },
                            action: { showAppearancePanel.toggle() }
                        )
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.bottom, DS.Spacing.m)

            VStack(spacing: DS.Spacing.s) {
                DSSectionHeader(title: localizer.text(.previewAndFineTuning))
                SettingsCard {
                    CommandSetEditorPane(
                        menu: $menu,
                        bundleIdentifier: bundleIdentifier,
                        hapticFeedbackEnabled: hapticFeedbackEnabled,
                        showAppearancePanel: $showAppearancePanel
                    )
                }
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.top, DS.Spacing.xs)
            .padding(.bottom, DS.Spacing.l)
        }
        .padding(.top, DS.Spacing.s + DS.Spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DS.Colors.canvasTop)
    }

    /// Та же шапка, что у страницы меню: иконка, название, действие справа.
    private var header: some View {
        PageTitleRow(title: String(format: localizer.text(.subMenuEditorTitleFormat), Self.appName(for: bundleIdentifier))) {
            if let icon = AppIconResolver.shared.icon(forBundleIdentifier: bundleIdentifier) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
            }
        } trailing: {
            Button(localizer.text(.subMenuResetToAutomatic), action: onReset)
                .buttonStyle(DSFieldButtonStyle())
                .help(localizer.text(.subMenuResetToAutomaticHelp))
        }
    }
}
