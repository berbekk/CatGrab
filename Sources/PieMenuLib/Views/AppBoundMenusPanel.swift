import SwiftUI
import AppKit

struct AppBoundMenusPanel: View {
    @Binding var config: PieConfiguration
    @Binding var selectedMenuId: UUID?
    let bundleIdLower: String
    let onAddSibling: () -> Void
    let onRemoveMenu: (UUID) -> Void
    @EnvironmentObject private var localizer: LocalizationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredSiblingMenuId: UUID?
    /// Пока не режим редактирования — строка целиком выбирает меню (как список в системных настройках); правка имени по двойному щелчку.
    @State private var editingSiblingMenuId: UUID?
    @State private var requestSiblingNameFieldFocus = false

    private func scrollAppMenuListToSelection(
        proxy: ScrollViewProxy,
        ids: [UUID],
        selectedId: UUID?,
        animated: Bool
    ) {
        guard ids.count > DS.Sizing.appBoundMenuMaxVisibleRows,
              let selectedId,
              ids.contains(selectedId) else { return }
        let reduce = reduceMotion
        let scroll = {
            if animated, !reduce {
                withAnimation(DS.Motion.slidePanelSpring) {
                    proxy.scrollTo(selectedId, anchor: .center)
                }
            } else {
                proxy.scrollTo(selectedId, anchor: .center)
            }
        }
        DispatchQueue.main.async(execute: scroll)
    }

    private var siblingMenuIds: [UUID] {
        config.menus.compactMap { m in
            (m.boundAppBundleId?.lowercased() == bundleIdLower) ? m.id : nil
        }
    }

    private func resignAppMenuNameFieldFocus() {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text(localizer.text(.appMenusEditorSection))
                .font(DS.Typography.section)
                .foregroundStyle(.secondary.opacity(0.7))
                .textCase(.uppercase)
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            SettingsCard {
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    if siblingMenuIds.count > DS.Sizing.appBoundMenuMaxVisibleRows {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                                    ForEach(siblingMenuIds, id: \.self) { menuId in
                                        appSiblingRowWithHover(menuId: menuId)
                                            .id(menuId)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: DS.Sizing.appBoundMenuScrollViewportHeight)
                            .scrollIndicators(.visible)
                            .onAppear {
                                scrollAppMenuListToSelection(
                                    proxy: proxy,
                                    ids: siblingMenuIds,
                                    selectedId: selectedMenuId,
                                    animated: false
                                )
                            }
                            .onChange(of: siblingMenuIds.count) { _ in
                                scrollAppMenuListToSelection(
                                    proxy: proxy,
                                    ids: siblingMenuIds,
                                    selectedId: selectedMenuId,
                                    animated: true
                                )
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: DS.Spacing.s) {
                            ForEach(siblingMenuIds, id: \.self) { menuId in
                                appSiblingRowWithHover(menuId: menuId)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: onAddSibling) {
                        Label(localizer.text(.addMenuForThisApp), systemImage: "plus.circle")
                            .font(DS.Typography.body)
                    }
                    .buttonStyle(.bordered)
                    .pointingHandCursor()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func appSiblingRowWithHover(menuId: UUID) -> some View {
        appSiblingRow(menuId: menuId, hoveredMenuId: hoveredSiblingMenuId)
            .onHover { hovering in
                if hovering {
                    hoveredSiblingMenuId = menuId
                    NSCursor.pointingHand.push()
                } else {
                    if hoveredSiblingMenuId == menuId {
                        hoveredSiblingMenuId = nil
                    }
                    NSCursor.pop()
                }
            }
    }

    private func appSiblingRow(menuId: UUID, hoveredMenuId: UUID?) -> some View {
        let isHovered = hoveredMenuId == menuId
        let isSel = selectedMenuId == menuId
        let nameBinding = Binding(
            get: { config.menus.first(where: { $0.id == menuId })?.name ?? "" },
            set: { newVal in
                guard let idx = config.menus.firstIndex(where: { $0.id == menuId }) else { return }
                var next = config
                next.menus[idx].name = newVal
                config = next
            }
        )
        let hotkeyBinding = Binding(
            get: { config.menus.first(where: { $0.id == menuId })?.hotkey ?? .empty },
            set: { newVal in
                guard let idx = config.menus.firstIndex(where: { $0.id == menuId }) else { return }
                var next = config
                next.menus[idx].hotkey = newVal
                config = next
            }
        )
        let rawName = config.menus.first(where: { $0.id == menuId })?.name ?? ""

        return HStack(alignment: .center, spacing: DS.Spacing.m) {
            if editingSiblingMenuId == menuId {
                HStack(alignment: .center, spacing: DS.Spacing.m) {
                    siblingRowSelectionStripe(isSelected: isSel)
                    AppMenuNameField(
                        text: nameBinding,
                        placeholder: localizer.text(.menuTitlePlaceholder),
                        maxWidth: .infinity,
                        requestFocus: $requestSiblingNameFieldFocus,
                        onResignFocus: {
                            editingSiblingMenuId = nil
                        }
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button {
                    resignAppMenuNameFieldFocus()
                    selectedMenuId = menuId
                    if editingSiblingMenuId != menuId {
                        editingSiblingMenuId = nil
                    }
                } label: {
                    HStack(alignment: .center, spacing: DS.Spacing.m) {
                        siblingRowSelectionStripe(isSelected: isSel)
                        siblingMenuNameReadOnly(
                            name: rawName,
                            placeholder: localizer.text(.menuTitlePlaceholder)
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(DSPlainButtonStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        resignAppMenuNameFieldFocus()
                        selectedMenuId = menuId
                        editingSiblingMenuId = menuId
                        requestSiblingNameFieldFocus = true
                    }
                )
            }

            HotkeyRecorderView(hotkey: hotkeyBinding)
                .frame(
                    minWidth: DS.Sizing.sidebarHotkeyColumnMaxWidth,
                    maxWidth: DS.Sizing.sidebarHotkeyColumnMaxWidth,
                    alignment: .leading
                )

            AppSiblingDeleteTrashButton(helpText: localizer.text(.delete)) {
                if editingSiblingMenuId == menuId {
                    editingSiblingMenuId = nil
                }
                onRemoveMenu(menuId)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
        .padding(.horizontal, DS.Spacing.m)
        .frame(maxWidth: .infinity, minHeight: DS.Sizing.appBoundMenuSiblingRowHeight, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .fill(rowBackgroundFill(isSelected: isSel, isHovered: isHovered))
                .animation(.easeInOut(duration: 0.14), value: isHovered)
                .animation(.easeInOut(duration: 0.14), value: isSel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .strokeBorder(
                    rowStrokeColor(isSelected: isSel, isHovered: isHovered),
                    lineWidth: isSel ? DS.Border.focus : DS.Border.hairline
                )
                .animation(.easeInOut(duration: 0.14), value: isHovered)
                .animation(.easeInOut(duration: 0.14), value: isSel)
        )
    }

    private func siblingRowSelectionStripe(isSelected: Bool) -> some View {
        Circle()
            .fill(isSelected ? DS.Colors.blueAccent : Color.primary.opacity(0.14))
            .frame(width: DS.Sizing.appMenuRowSelectionDot, height: DS.Sizing.appMenuRowSelectionDot)
            .accessibilityHidden(true)
    }

    private func siblingMenuNameReadOnly(
        name: String,
        placeholder: String
    ) -> some View {
        let showPlaceholder = name.isEmpty
        let line = showPlaceholder ? placeholder : name
        return Text(line)
            .font(.system(size: DS.Typography.bodySize, weight: .regular))
            .foregroundStyle(showPlaceholder ? Color.secondary.opacity(0.88) : Color.primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.leading, DS.Spacing.m)
            .padding(.trailing, DS.Spacing.m)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: DS.Sizing.fieldHeight, alignment: .leading)
            .contentShape(Rectangle())
    }

    private func rowBackgroundFill(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected { return Color.primary.opacity(0.08) }
        if isHovered { return Color.primary.opacity(0.055) }
        return Color.primary.opacity(0.025)
    }

    private func rowStrokeColor(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected { return DS.Colors.sidebarMenuSelectedStroke }
        if isHovered { return DS.Colors.stroke.opacity(0.65) }
        return DS.Colors.stroke.opacity(0.35)
    }
}
