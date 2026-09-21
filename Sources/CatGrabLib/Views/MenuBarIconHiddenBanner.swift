import SwiftUI

/// Подсказка, когда значок CatGrab не виден в строке меню: системный запрет macOS 26
/// («Строка меню → Разрешить в строке меню») или вырез экрана.
struct MenuBarIconHiddenBanner: View {
    @EnvironmentObject private var localizer: LocalizationStore
    @ObservedObject private var status = MenuBarIconStatus.shared

    var body: some View {
        if let problem = status.problem {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                Image(systemName: "menubar.arrow.up.rectangle")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizer.text(.menuBarIconHiddenTitle))
                        .font(DS.Typography.bodyEmphasized)
                    Text(localizer.text(bodyKey(for: problem)))
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DS.Spacing.m)
                if problem == .notPlacedBySystem {
                    Button(localizer.text(.menuBarIconOpenSettings)) {
                        MenuBarIconStatus.openMenuBarSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.Colors.blueAccent)
                    .pointingHandCursor()
                }
            }
            .padding(DS.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .fill(Color.orange.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.35), lineWidth: DS.Border.hairline)
            )
            .padding(.horizontal, DS.Spacing.l)
            .padding(.top, DS.Spacing.s)
        }
    }

    private func bodyKey(for problem: MenuBarIconStatus.Problem) -> L10nKey {
        switch problem {
        case .notPlacedBySystem: return .menuBarIconBlockedBody
        case .hiddenByNotch: return .menuBarIconHiddenBody
        }
    }
}
