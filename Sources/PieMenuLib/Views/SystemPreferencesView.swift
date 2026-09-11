import SwiftUI

/// Раздел настроек приложения: язык, конфигурация, автозапуск, TCC.
struct SystemPreferencesView: View {
    @Binding var appLanguage: AppLanguage
    @Binding var hapticFeedbackEnabled: Bool
    let onExportSettings: () -> Void
    let onImportSettings: () -> Void

    var body: some View {
        PermissionsSettingsView(
            appLanguage: $appLanguage,
            hapticFeedbackEnabled: $hapticFeedbackEnabled,
            onExportSettings: onExportSettings,
            onImportSettings: onImportSettings
        )
    }
}
