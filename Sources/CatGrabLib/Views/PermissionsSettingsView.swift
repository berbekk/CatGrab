import SwiftUI

/// Системные параметры: как в «Системных настройках» macOS — секция, под ней одна карточка,
/// строки внутри разделены линиями. У всех строк один облик (`SettingsRow`).
struct PermissionsSettingsView: View {
    @EnvironmentObject private var localizer: LocalizationStore
    @Binding var appLanguage: AppLanguage
    @Binding var hapticFeedbackEnabled: Bool
    @Binding var appearance: AppAppearance
    let onExportSettings: () -> Void
    let onImportSettings: () -> Void

    private static let pairedButtonMinWidth = (DS.Sizing.settingsControlWidth - DS.Spacing.s) / 2

    @State private var openAtLoginOn = false
    @State private var openAtLoginNeedsApproval = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                DSSectionHeader(title: localizer.text(.permissionsSectionPrivacy))
                PermissionAccessCard()

                DSSectionHeader(title: localizer.text(.permissionsSectionGeneral), topInset: DS.Spacing.xl)
                SettingsCard {
                    VStack(spacing: DS.Spacing.s) {
                        SettingsRow(localizer.text(.language)) {
                            DSPopUpPicker(
                                selection: $appLanguage,
                                options: AppLanguage.allCases.map { ($0, $0.displayName) },
                                accessibilityLabel: localizer.text(.language)
                            )
                        }
                        SettingsRowDivider()
                        SettingsRow(localizer.text(.interfaceAppearance)) {
                            DSPopUpPicker(
                                selection: $appearance,
                                options: AppAppearance.allCases.map { ($0, appearanceTitle($0)) },
                                accessibilityLabel: localizer.text(.interfaceAppearance)
                            )
                        }
                        SettingsRowDivider()
                        openAtLoginRow
                    }
                }

                DSSectionHeader(title: localizer.text(.permissionsSectionMenu), topInset: DS.Spacing.xl)
                SettingsCard {
                    VStack(spacing: DS.Spacing.s) {
                        SettingsRow(
                            localizer.text(.hapticFeedbackTitle),
                            subtitle: localizer.text(.hapticFeedbackSubtitle)
                        ) {
                            SettingsSwitch(isOn: $hapticFeedbackEnabled)
                        }
                        SettingsRowDivider()
                        SettingsRow(
                            localizer.text(.settingsMenuConfigurationTitle),
                            subtitle: localizer.text(.settingsMenuConfigurationSubtitle)
                        ) {
                            // Две кнопки вместе — не уже колонки контролов; длинные подписи просто шире.
                            HStack(spacing: DS.Spacing.s) {
                                Button(localizer.text(.settingsExport), action: onExportSettings)
                                Button(localizer.text(.settingsImport), action: onImportSettings)
                            }
                            .buttonStyle(DSFieldButtonStyle(minWidth: Self.pairedButtonMinWidth))
                        }
                    }
                }

                DSSectionHeader(title: localizer.text(.aboutSection), topInset: DS.Spacing.xl)
                AboutAppCard()
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.top, DS.Spacing.s)
            .padding(.bottom, DS.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.canvasTop)
        .onAppear {
            refreshLaunchAtLogin()
            DispatchQueue.main.asyncAfter(deadline: .now() + Timings.permissionsRefreshDelay) {
                refreshLaunchAtLogin()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshLaunchAtLogin()
        }
    }

    private func appearanceTitle(_ appearance: AppAppearance) -> String {
        switch appearance {
        case .system: return localizer.text(.interfaceAppearanceSystem)
        case .light: return localizer.text(.interfaceAppearanceLight)
        case .dark: return localizer.text(.interfaceAppearanceDark)
        }
    }

    private func refreshLaunchAtLogin() {
        openAtLoginOn = LaunchAtLoginService.isRegistered
        openAtLoginNeedsApproval = LaunchAtLoginService.needsUserApproval
    }

    private var openAtLoginToggleBinding: Binding<Bool> {
        Binding(
            get: { openAtLoginOn },
            set: { newValue in
                do {
                    try LaunchAtLoginService.setOpenAtLogin(newValue)
                } catch {}
                refreshLaunchAtLogin()
            }
        )
    }

    private var openAtLoginRow: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            SettingsRow(localizer.text(.openAtLoginTitle), subtitle: localizer.text(.openAtLoginSubtitle)) {
                SettingsSwitch(isOn: openAtLoginToggleBinding)
            }
            if openAtLoginNeedsApproval {
                Button(localizer.text(.openAtLoginOpenLoginItems)) {
                    LaunchAtLoginService.openLoginItemsSystemSettings()
                }
                .buttonStyle(.link)
                .font(DS.Typography.label)
                .pointingHandCursor()
            }
        }
    }
}
