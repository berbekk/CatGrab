import SwiftUI
import AppKit

/// Компактное окно результата экспорта/импорта настроек: успех с зелёной галочкой, ошибка — без «алертного» вида успеха.
struct BackupResultSheet: View {
    let isSuccess: Bool
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                if isSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(Color(nsColor: .systemGreen))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(title)
                        .font(DS.Typography.screenTitle)
                        .foregroundStyle(.primary)
                    Text(message)
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer(minLength: 0)
                Button("OK", action: onDismiss)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .pointingHandCursor()
            }
        }
        .padding(DS.Spacing.l)
        .frame(minWidth: 320, maxWidth: 420)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.Colors.panelTop)
                .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        }
        .padding(DS.Spacing.xl)
    }
}
