import SwiftUI

struct ApplySharedMenuSettingsSheet: View {
    let targets: [(UUID, String)]
    @Binding var selectedIds: Set<UUID>
    var onConfirm: () -> Void
    var onDismiss: () -> Void

    @EnvironmentObject private var localizer: LocalizationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(localizer.text(.applySharedMenuSettingsSheetTitle))
                    .font(DS.Typography.screenTitle)
                Text(localizer.text(.applySharedMenuSettingsSheetHint))
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.m)

            // Та же карточка со строками, что и в настройках, — а не системный список с полосами.
            ScrollView {
                SettingsCard {
                    VStack(spacing: DS.Spacing.s) {
                        ForEach(Array(targets.enumerated()), id: \.element.0) { index, pair in
                            if index > 0 {
                                SettingsRowDivider()
                            }
                            targetRow(id: pair.0, name: pair.1)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
            }

            HStack(spacing: DS.Spacing.s) {
                Spacer()
                Button(localizer.text(.applySharedMenuSettingsDismiss)) {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                .pointingHandCursor()
                Button(localizer.text(.applySharedMenuSettingsConfirm)) {
                    onConfirm()
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedIds.isEmpty)
                .pointingHandCursor()
            }
            .padding(DS.Spacing.xl)
        }
        .frame(minWidth: 400, minHeight: 400)
        .background(DS.Colors.canvasTop)
    }

    private func targetRow(id: UUID, name: String) -> some View {
        Toggle(isOn: Binding(
            get: { selectedIds.contains(id) },
            set: { on in
                if on {
                    selectedIds.insert(id)
                } else {
                    selectedIds.remove(id)
                }
            }
        )) {
            Text(name)
                .font(DS.Typography.body)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.checkbox)
        .frame(minHeight: 24)
    }
}
