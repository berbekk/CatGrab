import SwiftUI
import AppKit

/// Строки прав с живым статусом — в одной карточке, как остальные группы настроек. Кнопка вызывает
/// системный диалог (CatGrab уже подставлен в список) и открывает нужную панель настроек.
struct PermissionAccessCard: View {
    @EnvironmentObject private var localizer: LocalizationStore
    @ObservedObject private var monitor = PermissionsMonitor.shared

    var body: some View {
        SettingsCard {
            VStack(spacing: DS.Spacing.s) {
                PermissionRow(
                    granted: monitor.snapshot.accessibilityTrusted,
                    title: localizer.text(.permissionAccessibilityRow),
                    hint: localizer.text(.permissionAccessibilityHint),
                    statusText: statusText(granted: monitor.snapshot.accessibilityTrusted),
                    buttonTitle: localizer.text(.permissionOpenSettings),
                    action: PermissionsSnapshot.requestAccessibility
                )
                SettingsRowDivider()
                PermissionRow(
                    granted: monitor.snapshot.inputMonitoringGranted,
                    title: localizer.text(.permissionInputMonitoringRow),
                    hint: localizer.text(.permissionInputMonitoringHint),
                    statusText: statusText(granted: monitor.snapshot.inputMonitoringGranted),
                    buttonTitle: localizer.text(.permissionOpenSettings),
                    action: PermissionsSnapshot.requestInputMonitoring
                )
            }
        }
        .onAppear { monitor.refresh() }
    }

    private func statusText(granted: Bool) -> String {
        localizer.text(granted ? .permissionStatusGranted : .permissionStatusRequired)
    }
}

private struct PermissionRow: View {
    let granted: Bool
    let title: String
    let hint: String
    let statusText: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(granted ? Color.green : Color.orange)
                .frame(height: 17)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                Text(hint)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(statusText)
                    .font(DS.Typography.label)
                    .foregroundStyle(granted ? Color.green : Color.orange)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !granted {
                Button(buttonTitle, action: action)
                    .buttonStyle(DSFieldButtonStyle(isProminent: true))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
