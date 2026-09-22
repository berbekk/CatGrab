import SwiftUI

/// Показывать ли в настройках «CatGrab запущен, нажмите …». Включается один раз — когда тур
/// закончен (в том числе после перезапуска ради прав); крестик убирает.
@MainActor
final class ReadyBannerState: ObservableObject {
    static let shared = ReadyBannerState()
    @Published var isShown = false
    private init() {}
}

/// Первое, что видно после знакомства: приложение работает, вот сочетание, вот где его поменять.
struct ReadyBanner: View {
    let hotkey: HotkeyConfig
    @ObservedObject private var state = ReadyBannerState.shared
    @EnvironmentObject private var localizer: LocalizationStore

    var body: some View {
        if state.isShown {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.green)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizer.text(.onboardingReadyBannerTitle))
                        .font(DS.Typography.bodyEmphasized)
                    Text(String(
                        format: localizer.text(.onboardingReadyBannerBodyFormat),
                        hotkey.isEmpty ? localizer.text(.unassigned) : hotkey.glyphString
                    ))
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DS.Spacing.m)
                PanelCloseButton { state.isShown = false }
            }
            .padding(DS.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .fill(Color.green.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .strokeBorder(Color.green.opacity(0.35), lineWidth: DS.Border.hairline)
            )
            .padding(.horizontal, DS.Spacing.l)
            .padding(.top, DS.Spacing.s)
        }
    }
}
