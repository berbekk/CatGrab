import SwiftUI

/// Вышла новая версия: что это за версия и где её взять. Крестик — «не напоминать об этой версии».
struct UpdateAvailableBanner: View {
    @ObservedObject private var updates = UpdateChecker.shared
    @EnvironmentObject private var localizer: LocalizationStore

    var body: some View {
        if let update = updates.updateToAnnounce {
            HStack(alignment: .center, spacing: DS.Spacing.m) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(DS.Colors.blueAccent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: localizer.text(.updatesAvailableFormat), update.version))
                        .font(DS.Typography.bodyEmphasized)
                    Text(localizer.text(.updatesBannerBody))
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DS.Spacing.m)
                Button(localizer.text(.updatesDownload)) {
                    updates.openDownloadPage(for: update)
                }
                .buttonStyle(DSFieldButtonStyle(isProminent: true))
                PanelCloseButton(help: localizer.text(.updatesSkip)) { updates.skip(update) }
            }
            .padding(DS.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(DS.Colors.blueAccent.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Colors.blueAccent.opacity(0.35), lineWidth: DS.Border.hairline)
            )
            .padding(.horizontal, DS.Spacing.l)
            .padding(.top, DS.Spacing.xs)
            .padding(.bottom, DS.Spacing.xs)
        }
    }
}

/// Итог проверки обновлений — строка под версией в карточке «О программе». Пока не проверяли — пусто.
struct UpdateStatusLabel: View {
    @ObservedObject private var updates = UpdateChecker.shared
    @EnvironmentObject private var localizer: LocalizationStore

    var body: some View {
        switch updates.state {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: DS.Spacing.xs + 2) {
                ProgressView()
                    .controlSize(.mini)
                Text(localizer.text(.updatesChecking))
                    .foregroundStyle(.secondary)
            }
            .font(DS.Typography.label)
        case .upToDate:
            label(localizer.text(.updatesUpToDate), symbol: "checkmark.circle.fill", color: .green)
        case .available(let update):
            label(
                String(format: localizer.text(.updatesAvailableFormat), update.version),
                symbol: "arrow.down.circle.fill",
                color: DS.Colors.blueAccent
            )
        case .failed:
            label(localizer.text(.updatesCheckFailed), symbol: "exclamationmark.triangle.fill", color: .orange)
        }
    }

    private func label(_ text: String, symbol: String, color: Color) -> some View {
        HStack(spacing: DS.Spacing.xs + 2) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(text)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(DS.Typography.label)
    }
}

/// Одно действие рядом с версией: проверить обновления или, когда новая версия найдена, скачать её.
struct UpdateActionButton: View {
    @ObservedObject private var updates = UpdateChecker.shared
    @EnvironmentObject private var localizer: LocalizationStore

    var body: some View {
        if case .available(let update) = updates.state {
            Button(localizer.text(.updatesDownload)) {
                updates.openDownloadPage(for: update)
            }
            .buttonStyle(DSFieldButtonStyle(isProminent: true))
        } else {
            Button(localizer.text(.updatesCheckNow)) {
                Task { await updates.check(userInitiated: true) }
            }
            .buttonStyle(DSFieldButtonStyle())
            .disabled(updates.state == .checking)
        }
    }
}
