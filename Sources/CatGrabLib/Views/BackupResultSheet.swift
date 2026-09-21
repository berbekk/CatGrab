import SwiftUI
import AppKit

/// Компактное окно результата экспорта/импорта настроек: успех — с зелёной галочкой, ошибка — с оранжевым
/// предупреждением. Раскладка у обоих одна, меняются только значок и цвет.
struct BackupResultSheet: View {
    let isSuccess: Bool
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color(nsColor: isSuccess ? .systemGreen : .systemOrange))
                    .accessibilityHidden(true)
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
                    .pointingHandCursor()
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 420)
        .background(DS.Colors.canvasTop)
    }
}
