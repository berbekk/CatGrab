import SwiftUI
import AppKit

/// Строки прав с живым статусом. Кнопка вызывает системный диалог (PieMenu уже подставлен в список)
/// и открывает нужную панель настроек.
struct PermissionAccessCard: View {
    @EnvironmentObject private var localizer: LocalizationStore
    @ObservedObject private var monitor = PermissionsMonitor.shared

    var body: some View {
        VStack(spacing: DS.Spacing.s) {
            PermissionRow(
                granted: monitor.snapshot.accessibilityTrusted,
                title: localizer.text(.permissionAccessibilityRow),
                hint: localizer.text(.permissionAccessibilityHint),
                statusText: statusText(granted: monitor.snapshot.accessibilityTrusted),
                buttonTitle: localizer.text(.permissionOpenSettings),
                action: PermissionsSnapshot.requestAccessibility
            )
            PermissionRow(
                granted: monitor.snapshot.inputMonitoringGranted,
                title: localizer.text(.permissionInputMonitoringRow),
                hint: localizer.text(.permissionInputMonitoringHint),
                statusText: statusText(granted: monitor.snapshot.inputMonitoringGranted),
                buttonTitle: localizer.text(.permissionOpenSettings),
                action: PermissionsSnapshot.requestInputMonitoring
            )
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
                .font(.system(size: 18))
                .foregroundStyle(granted ? Color.green : Color.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DS.Typography.bodyEmphasized)
                Text(hint)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(statusText)
                    .font(DS.Typography.label)
                    .foregroundStyle(granted ? Color.green : Color.orange)
            }
            Spacer(minLength: DS.Spacing.m)
            if !granted {
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(DS.Colors.blueAccent)
                    .pointingHandCursor()
            }
        }
        .padding(DS.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .strokeBorder(DS.Colors.stroke, lineWidth: DS.Border.hairline)
        )
    }
}
