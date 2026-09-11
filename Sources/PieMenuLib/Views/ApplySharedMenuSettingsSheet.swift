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
                    .font(DS.Typography.bodyEmphasized)
                Text(localizer.text(.applySharedMenuSettingsSheetHint))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.top, DS.Spacing.l)
            .padding(.bottom, DS.Spacing.s)

            List {
                ForEach(targets, id: \.0) { pair in
                    let id = pair.0
                    let name = pair.1
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
                    }
                    .toggleStyle(.checkbox)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(minHeight: 280)

            HStack {
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
            .padding(DS.Spacing.l)
        }
        .frame(minWidth: 400, minHeight: 400)
        .background(DS.Colors.canvasTop)
    }
}
