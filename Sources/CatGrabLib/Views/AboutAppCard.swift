import AppKit
import SwiftUI

/// «О приложении» в общих настройках: иконка, версия, автор и куда написать.
struct AboutAppCard: View {
    @EnvironmentObject private var localizer: LocalizationStore

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                HStack(spacing: DS.Spacing.m) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 52, height: 52)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CatGrab")
                            .font(DS.Typography.screenTitle)
                        if let version = AppInfo.version {
                            Text(String(format: localizer.text(.versionFormat), version))
                                .font(DS.Typography.label)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(localizer.text(.developerLabel)): \(AppInfo.developerName(localizer.language))")
                            .font(DS.Typography.label)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                SettingsRowDivider()

                HStack(spacing: DS.Spacing.s) {
                    link("Telegram", icon: "paperplane.fill", url: AppInfo.telegramURL)
                    link("GitHub", icon: "chevron.left.forwardslash.chevron.right", url: AppInfo.githubURL)
                    Spacer(minLength: 0)
                    link(localizer.text(.reportIssueAction), icon: "exclamationmark.bubble", url: AppInfo.issuesURL)
                }
            }
        }
    }

    private func link(_ title: String, icon: String, url: URL) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            Label(title, systemImage: icon)
        }
        .buttonStyle(DSFieldButtonStyle())
        .help(url.absoluteString)
    }
}
