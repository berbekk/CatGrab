import SwiftUI

/// Раздел настроек приложения: язык, оформление, конфигурация, автозапуск, TCC.
struct SystemPreferencesView: View {
    @Binding var appLanguage: AppLanguage
    @Binding var hapticFeedbackEnabled: Bool
    @Binding var appearance: AppAppearance
    let onExportSettings: () -> Void
    let onImportSettings: () -> Void

    var body: some View {
        PermissionsSettingsView(
            appLanguage: $appLanguage,
            hapticFeedbackEnabled: $hapticFeedbackEnabled,
            appearance: $appearance,
            onExportSettings: onExportSettings,
            onImportSettings: onImportSettings
        )
    }
}
