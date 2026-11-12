import SwiftUI

struct SettingsSaveFailureBanner: View {
    let retry: () -> Void
    @EnvironmentObject private var localizer: LocalizationStore

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.orange)
                .accessibilityHidden(true)
            Text(localizer.text(.settingsSaveFailed))
                .font(DS.Typography.label)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(localizer.text(.retrySave), action: retry)
                .buttonStyle(DSFieldButtonStyle())
        }
        .padding(DS.Spacing.m)
        .background(Color.orange.opacity(0.10))
    }
}
