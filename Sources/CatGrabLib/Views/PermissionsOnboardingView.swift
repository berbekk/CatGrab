import SwiftUI

struct PermissionsOnboardingView: View {
    @EnvironmentObject private var localizer: LocalizationStore
    @ObservedObject private var monitor = PermissionsMonitor.shared
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                Text(localizer.text(.permissionsWelcomeTitle))
                    .font(DS.Typography.screenTitle)
                Text(localizer.text(.permissionsWelcomeBody))
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PermissionAccessCard()

            MenuBarIconHiddenBanner()
                .padding(.horizontal, -DS.Spacing.l)

            HStack {
                Spacer()
                if monitor.snapshot.allRequiredGranted {
                    Button(localizer.text(.permissionsContinue)) { onContinue() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .tint(DS.Colors.blueAccent)
                        .pointingHandCursor()
                } else {
                    Button(localizer.text(.permissionsSkip)) { onContinue() }
                        .buttonStyle(.bordered)
                        .pointingHandCursor()
                }
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 480)
    }
}
