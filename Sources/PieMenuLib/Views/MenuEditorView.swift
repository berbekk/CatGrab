import SwiftUI
import AppKit

struct MenuEditorView: View {
    @Binding var menu: PieMenu
    @Binding var hapticFeedbackEnabled: Bool
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

    /// Как блоки в `SettingsSidebarView.menuListStack`: есть ли верхняя секция до превью.
    private var hasMenuSettingsChrome: Bool {
        menu.isRunningAppsMenu
    }

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

    @ViewBuilder
    private var menuSettingsSection: some View {
        if hasMenuSettingsChrome {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                if menu.isRunningAppsMenu {
                    sectionTitle(localizer.text(.runningAppsSection), isUppercase: true)
                    SettingsCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.s) {
                            runningAppsHotkeyCompactRow
                            Divider()
                                .opacity(0.35)
                            runningAppsExclusionsContent
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.bottom, DS.Spacing.m)
        }
    }

    private var runningAppsHotkeyCompactRow: some View {
        HStack(alignment: .center, spacing: DS.Spacing.m) {
            Text(localizer.text(.hotkey))
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            HotkeyRecorderView(hotkey: $menu.hotkey)
                .frame(maxWidth: 280, alignment: .trailing)
        }
    }

    private var runningAppsExclusionsContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text(localizer.text(.runningAppsExclusions))
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(localizer.text(.runningAppsExclusionsExplainer))
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                addRunningAppExclusion()
            } label: {
                Label(localizer.text(.addExclusion), systemImage: "plus.circle")
                    .font(DS.Typography.body)
            }
            .buttonStyle(.bordered)
            .pointingHandCursor()

            if !menu.runningAppsExcludedBundleIds.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    ForEach(menu.runningAppsExcludedBundleIds, id: \.self) { bundleId in
                        HStack(spacing: DS.Spacing.s) {
                            if let nsImage = AppIconResolver.shared.icon(forBundleIdentifier: bundleId) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .frame(width: 18, height: 18)
                            }
                            Text(exclusionDisplayName(bundleId: bundleId))
                                .font(DS.Typography.bodyCompact)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Button {
                                removeRunningAppExclusion(bundleId: bundleId)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(DSPlainButtonStyle())
                            .help(localizer.text(.removeExclusion))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(DS.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
                        onAddItem: menu.isRunningAppsMenu ? nil : addItem,
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
                isAppMenu: !menu.isGlobal,
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

    /// Соответствует `SettingsSidebarView.sectionLabel` (отступ сверху у подписи секции).
    private func sectionTitle(_ title: String, isUppercase: Bool = true) -> some View {
        Text(title)
            .font(DS.Typography.section)
            .foregroundStyle(.secondary.opacity(0.7))
            .textCase(isUppercase ? .uppercase : nil)
            .tracking(isUppercase ? 0.5 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DS.Spacing.m)
    }

    private func sectionBlock<Content: View>(
        title: String,
        isUppercase: Bool = true,
        fillBackground: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: DS.Spacing.s) {
            sectionTitle(title, isUppercase: isUppercase)
            SettingsCard(fillBackground: fillBackground) {
                content()
            }
            .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DS.Spacing.l)
        .padding(.top, hasMenuSettingsChrome ? DS.Spacing.xs : 0)
        .padding(.bottom, DS.Spacing.l)
    }

    // MARK: - Actions

    private func addItem() {
        let usedIndices = Set(menu.items.map { $0.sectorIndex })
        let nextIndex = (0...).first { !usedIndices.contains($0) } ?? menu.items.count
        let item = PieMenuItem(
            title: localizer.text(.newItem),
            icon: PieMenuItem.unassignedSFSymbol,
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
    @State private var showPanel = false
    var body: some View {
        MenuEditorView(
            menu: $menu,
            hapticFeedbackEnabled: $hapticFeedbackEnabled,
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

