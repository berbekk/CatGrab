import SwiftUI

struct PermissionsSettingsView: View {
    @EnvironmentObject private var localizer: LocalizationStore
    @Binding var appLanguage: AppLanguage
    @Binding var hapticFeedbackEnabled: Bool
    let onExportSettings: () -> Void
    let onImportSettings: () -> Void

    @State private var openAtLoginOn = false
    @State private var openAtLoginNeedsApproval = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    sectionLabel(localizer.text(.permissionsSectionPrivacy), includeTopInset: false)
                    PermissionAccessCard()
                }

                sectionLabel(localizer.text(.permissionsSectionGeneral))

                languageCard
                openAtLoginCard

                sectionLabel(localizer.text(.permissionsSectionMenu))

                hapticFeedbackCard
                menuConfigurationCard
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.top, DS.Spacing.s + DS.Spacing.m)
            .padding(.bottom, DS.Spacing.m)
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

    private func refreshLaunchAtLogin() {
        openAtLoginOn = LaunchAtLoginService.isRegistered
        openAtLoginNeedsApproval = LaunchAtLoginService.needsUserApproval
    }

    private func sectionLabel(_ title: String, includeTopInset: Bool = true) -> some View {
        Text(title)
            .font(DS.Typography.section)
            .foregroundStyle(.secondary.opacity(0.7))
            .textCase(.uppercase)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, includeTopInset ? DS.Spacing.m : 0)
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

    private var languageCard: some View {
        HStack(alignment: .center, spacing: DS.Spacing.m) {
            Text(localizer.text(.language))
                .font(DS.Typography.bodyEmphasized)
            Spacer(minLength: DS.Spacing.m)
            Picker("", selection: $appLanguage) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
        .padding(DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .strokeBorder(DS.Colors.stroke, lineWidth: DS.Border.hairline)
        )
    }

    private var hapticFeedbackCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizer.text(.hapticFeedbackTitle))
                        .font(DS.Typography.bodyEmphasized)
                    Text(localizer.text(.hapticFeedbackSubtitle))
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DS.Spacing.m)
                Toggle("", isOn: $hapticFeedbackEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
        .padding(DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .strokeBorder(DS.Colors.stroke, lineWidth: DS.Border.hairline)
        )
    }

    private var menuConfigurationCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text(localizer.text(.settingsMenuConfigurationTitle))
                .font(DS.Typography.bodyEmphasized)
            HStack(spacing: DS.Spacing.m) {
                Button(localizer.text(.settingsExport)) {
                    onExportSettings()
                }
                .buttonStyle(.bordered)
                .pointingHandCursor()
                Button(localizer.text(.settingsImport)) {
                    onImportSettings()
                }
                .buttonStyle(.bordered)
                .pointingHandCursor()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .strokeBorder(DS.Colors.stroke, lineWidth: DS.Border.hairline)
        )
    }

    private var openAtLoginCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizer.text(.openAtLoginTitle))
                        .font(DS.Typography.bodyEmphasized)
                    Text(localizer.text(.openAtLoginSubtitle))
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DS.Spacing.m)
                Toggle("", isOn: openAtLoginToggleBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            if openAtLoginNeedsApproval {
                Button(localizer.text(.openAtLoginOpenLoginItems)) {
                    LaunchAtLoginService.openLoginItemsSystemSettings()
                }
                .buttonStyle(.link)
                .controlSize(.small)
                .pointingHandCursor()
            }
        }
        .padding(DS.Spacing.m)
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

