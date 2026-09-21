import SwiftUI
import AppKit

struct MenuEditorView: View {
    @Binding var menu: PieMenu
    @Binding var hapticFeedbackEnabled: Bool
    /// Касание трекпада этого меню. Запись снимает то же число пальцев с других меню.
    @Binding var trackpadFingerCount: Int
    /// Число пальцев → название другого меню, которое сейчас открывается этим касанием.
    var trackpadFingerCountOwners: [Int: String]
    @Binding var showAppearancePanel: Bool
    /// Остальные меню (id и название) для копирования видимых настроек.
    var otherMenuApplyTargets: [(UUID, String)]
    var onApplySharedSettingsToMenuIds: (Set<UUID>) -> Void
    @EnvironmentObject private var localizer: LocalizationStore

    @State private var selectedItemId: UUID?
    @State private var showApplyTargetsSheet = false
    @State private var applyTargetsSelection: Set<UUID> = []

    private var showingInspector: Bool {
        selectedItemId != nil
    }

    private static let inspectorDrawerWidth: CGFloat = 340

    var body: some View {
        VStack(spacing: 0) {
            menuSettingsSection
            previewSection
                .frame(minHeight: 0)
                .layoutPriority(1)
        }
        .padding(.top, DS.Spacing.s)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: showingInspector)
        .background(DS.Colors.canvasTop)
        .sheet(isPresented: $showApplyTargetsSheet) {
            ApplySharedMenuSettingsSheet(
                targets: otherMenuApplyTargets,
                selectedIds: $applyTargetsSelection,
                onConfirm: { onApplySharedSettingsToMenuIds(applyTargetsSelection) },
                onDismiss: { showApplyTargetsSheet = false }
            )
            .environmentObject(localizer)
        }
    }

    // MARK: - Menu Settings

    /// У каждого меню сверху одна и та же карточка «хоткей + жест»: как меню открывается, настраивается
    /// в самом меню. Строки — общие `SettingsRow`, контролы справа одной ширины.
    private var menuSettingsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            switch menu.kind {
            case .standard:
                DSSectionHeader(title: localizer.text(.menuOpeningSection))
                SettingsCard {
                    VStack(spacing: DS.Spacing.s) {
                        hotkeyRow
                        SettingsRowDivider()
                        trackpadGestureRow
                    }
                }
            case .runningApps:
                DSSectionHeader(title: localizer.text(.runningAppsSection))
                SettingsCard {
                    VStack(spacing: DS.Spacing.s) {
                        hotkeyRow
                        SettingsRowDivider()
                        trackpadGestureRow
                        SettingsRowDivider()
                        runningAppsExclusionsContent
                    }
                }
            case .appCommands:
                DSSectionHeader(title: localizer.text(.appCommandsSection))
                SettingsCard {
                    VStack(spacing: DS.Spacing.s) {
                        hotkeyRow
                        SettingsRowDivider()
                        trackpadGestureRow
                    }
                }
                appCommandsFootnote
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.bottom, DS.Spacing.m)
    }

    private var hotkeyRow: some View {
        SettingsRow(localizer.text(.hotkey)) {
            HotkeyRecorderView(hotkey: $menu.hotkey)
                .frame(width: DS.Sizing.settingsControlWidth)
        }
    }

    /// Касание трекпада, которое открывает это меню. Число, занятое другим меню, подписано его названием:
    /// выбор заберёт касание у того меню.
    private var trackpadGestureRow: some View {
        SettingsRow(localizer.text(.trackpadGestureTitle)) {
            DSPopUpPicker(
                selection: $trackpadFingerCount,
                options: [(0, localizer.text(.trackpadGestureOff))]
                    + TrackpadGesture.supportedFingerCounts.map { ($0, trackpadGestureOptionTitle($0)) },
                accessibilityLabel: localizer.text(.trackpadGestureTitle)
            )
        }
        .help(localizer.text(.trackpadGestureSubtitle))
    }

    private func trackpadGestureOptionTitle(_ count: Int) -> String {
        let title = String(format: localizer.text(.trackpadGestureFingersFormat), count)
        guard let owner = trackpadFingerCountOwners[count] else { return title }
        return "\(title) — \(owner)"
    }

    /// Исключения — такая же строка, как остальные; выбранные приложения идут строками под ней.
    private var runningAppsExclusionsContent: some View {
        VStack(spacing: DS.Spacing.s) {
            SettingsRow(
                localizer.text(.runningAppsExclusions),
                subtitle: localizer.text(.runningAppsExclusionsExplainer)
            ) {
                Button(action: addRunningAppExclusion) {
                    Label(localizer.text(.addExclusion), systemImage: "plus")
                }
                .buttonStyle(DSFieldButtonStyle(width: DS.Sizing.settingsControlWidth))
            }
            ForEach(menu.runningAppsExcludedBundleIds, id: \.self) { bundleId in
                SettingsRowDivider()
                exclusionRow(bundleId: bundleId)
            }
        }
    }

    private func exclusionRow(bundleId: String) -> some View {
        HStack(spacing: DS.Spacing.s) {
            Group {
                if let nsImage = AppIconResolver.shared.icon(forBundleIdentifier: bundleId) {
                    Image(nsImage: nsImage).resizable()
                } else {
                    Image(systemName: "app.dashed").foregroundStyle(.secondary)
                }
            }
            .frame(width: 20, height: 20)
            Text(exclusionDisplayName(bundleId: bundleId))
                .font(DS.Typography.body)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                removeRunningAppExclusion(bundleId: bundleId)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(DSPlainButtonStyle())
            .iconOnlyHelp(localizer.text(.removeExclusion))
        }
        .frame(minHeight: DS.Sizing.settingsRowMinHeight)
    }

    /// Что это за меню и где менять команды отдельных приложений — подпись под карточкой.
    private var appCommandsFootnote: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(localizer.text(.appCommandsMenuPurpose))
            Text(localizer.text(.appCommandsCustomizeHint))
        }
        .font(DS.Typography.label)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, DS.Spacing.m)
    }

    private func exclusionDisplayName(bundleId: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return bundleId
    }

    private func addRunningAppExclusion() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = localizer.text(.select)
        panel.message = localizer.text(.runningAppsExclusionsExplainer)
        guard panel.runModal() == .OK, let url = panel.url,
              let descriptor = AppDescriptorResolver.resolve(from: url) else { return }
        let bid = descriptor.bundleIdentifier
        let bidKey = bid.lowercased()
        guard !menu.runningAppsExcludedBundleIds.contains(where: { $0.lowercased() == bidKey }) else { return }
        menu.runningAppsExcludedBundleIds.append(bid)
    }

    private func removeRunningAppExclusion(bundleId: String) {
        let key = bundleId.lowercased()
        menu.runningAppsExcludedBundleIds.removeAll { $0.lowercased() == key }
    }

    // MARK: - Preview

    private var previewSection: some View {
        sectionBlock(title: localizer.text(.previewAndFineTuning)) {
            GeometryReader { geo in
                ZStack(alignment: .trailing) {
                    MenuPreviewView(
                        menu: $menu,
                        selectedItemId: $selectedItemId,
                        hapticFeedbackEnabled: hapticFeedbackEnabled,
                        isAppearancePanelVisible: showAppearancePanel,
                        onToggleAppearancePanel: { showAppearancePanel.toggle() },
                        onAddItem: menu.isDynamicMenu ? nil : addItem,
                        applySharedStyleActions: otherMenuApplyTargets.isEmpty
                            ? nil
                            : (
                                applyToAll: { onApplySharedSettingsToMenuIds(Set(otherMenuApplyTargets.map(\.0))) },
                                chooseTargets: {
                                    applyTargetsSelection = []
                                    showApplyTargetsSheet = true
                                }
                            )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if showingInspector {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { selectedItemId = nil }
                    }

                    selectedItemEditor(maxWidth: min(Self.inspectorDrawerWidth, geo.size.width * 0.46))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: showingInspector)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func selectedItemEditor(maxWidth: CGFloat) -> some View {
        if let id = selectedItemId,
           let index = menu.items.firstIndex(where: { $0.id == id }) {
            let inspectorRadius = DS.Radius.card
            ItemEditorView(
                item: Binding(
                    get: { menu.items[index] },
                    set: { menu.items[index] = $0 }
                ),
                onClose: { selectedItemId = nil },
                onDelete: removeSelectedItem
            )
            .frame(width: max(260, maxWidth))
            .clipShape(RoundedRectangle(cornerRadius: inspectorRadius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: inspectorRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [DS.Colors.panelTop, DS.Colors.panelBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: inspectorRadius, style: .continuous)
                    .strokeBorder(DS.Colors.stroke, lineWidth: DS.Border.hairline)
            )
            .padding(DS.Spacing.m)
            .id(id)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            ))
        }
    }

    private func sectionBlock<Content: View>(
        title: String,
        fillBackground: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: DS.Spacing.s) {
            DSSectionHeader(title: title)
            SettingsCard(fillBackground: fillBackground) {
                content()
            }
            .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DS.Spacing.l)
        .padding(.top, DS.Spacing.xs)
        .padding(.bottom, DS.Spacing.l)
    }

    // MARK: - Actions

    private func addItem() {
        let usedIndices = Set(menu.items.map { $0.sectorIndex })
        let nextIndex = (0...).first { !usedIndices.contains($0) } ?? menu.items.count
        let item = PieMenuItem(
            title: localizer.text(.newItem),
            icon: PieMenuItem.randomUnassignedSymbol(avoiding: Set(menu.items.map(\.icon))),
            action: .unassigned,
            color: PieMenuItem.paletteColor(for: nextIndex),
            sectorIndex: nextIndex
        )
        withoutAnimation {
            menu.items.append(item)
            menu.snapRotationToAestheticAnchor()
        }
    }

    private func removeSelectedItem() {
        guard let id = selectedItemId else { return }
        guard menu.items.count > PieMenuItem.minItemCount else { return }
        withoutAnimation {
            menu.items.removeAll { $0.id == id }
            menu.snapRotationToAestheticAnchor()
        }
        selectedItemId = nil
    }

}

private struct MenuEditorPreview: View {
    @State private var menu = PieConfiguration.defaultConfig.menus[0]
    @State private var hapticFeedbackEnabled = true
    @State private var trackpadFingerCount = 0
    @State private var showPanel = false
    var body: some View {
        MenuEditorView(
            menu: $menu,
            hapticFeedbackEnabled: $hapticFeedbackEnabled,
            trackpadFingerCount: $trackpadFingerCount,
            trackpadFingerCountOwners: [:],
            showAppearancePanel: $showPanel,
            otherMenuApplyTargets: [],
            onApplySharedSettingsToMenuIds: { _ in }
        )
            .frame(width: 800, height: 600)
            .preferredColorScheme(.dark)
            .environmentObject(LocalizationStore(language: .russian))
    }
}

#Preview("MenuEditor") {
    MenuEditorPreview()
}
