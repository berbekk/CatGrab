import AppKit
import SwiftUI

/// Общий «скелет» полей записи хоткея: одинаковые цвета, анимация, рамка и курсор
/// и для `HotkeyRecorderView`, и для `KeystrokeRecorderView`. Облик — как у остальных полей
/// (`dsFieldChrome`); акцентом выделяется только запись.
private struct RecorderFieldChrome<Content: View>: View {
    let isRecording: Bool
    @Binding var isHovered: Bool
    let onTap: () -> Void
    /// Для встроенного `NSTextField` курсор задаёт сам контрол (рука / I‑beam).
    var usePointingHandCursor: Bool
    @ViewBuilder let content: Content

    init(
        isRecording: Bool,
        isHovered: Binding<Bool>,
        onTap: @escaping () -> Void,
        usePointingHandCursor: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.isRecording = isRecording
        self._isHovered = isHovered
        self.onTap = onTap
        self.usePointingHandCursor = usePointingHandCursor
        self.content = content()
    }

    private var chrome: some View {
        content
            .padding(.horizontal, DS.Spacing.fieldInsetHorizontal)
            .frame(height: DS.Sizing.fieldHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsFieldChrome(isHovered: isHovered, isFocused: isRecording)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.15), value: isRecording)
            .animation(.easeInOut(duration: 0.1), value: isHovered)
    }

    var body: some View {
        Group {
            if usePointingHandCursor {
                chrome.pointingHandCursor()
            } else {
                chrome
            }
        }
    }
}

/// Поле «быстрая клавиша пункта» в том же визуальном стиле, что и запись хоткея.
struct ShortcutDigitKeyField: View {
    let placeholder: String
    @Binding var text: String
    @EnvironmentObject private var localizer: LocalizationStore
    @State private var isHovered = false
    @State private var isFocused = false
    @State private var requestFocus = false

    private static var fieldFont: NSFont {
        .systemFont(ofSize: 12, weight: .semibold)
    }

    var body: some View {
        RecorderFieldChrome(
            isRecording: false,
            isHovered: $isHovered,
            onTap: { requestFocus = true },
            usePointingHandCursor: false,
            content: {
                HStack(spacing: DS.Spacing.s) {
                    Image(systemName: "textformat.123")
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    PlainTextFieldRepresentable(
                        text: $text,
                        placeholder: placeholder,
                        isFocused: $isFocused,
                        commitsOnBlur: false,
                        requestFocus: $requestFocus,
                        controlFont: Self.fieldFont,
                        onSubmit: {
                            NSApp.keyWindow?.makeFirstResponder(nil)
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !text.isEmpty {
                        FieldClearButton {
                            text = ""
                            DispatchQueue.main.async {
                                NSApp.keyWindow?.makeFirstResponder(nil)
                            }
                        }
                        .help(localizer.text(.reset))
                    }
                }
            }
        )
    }
}

/// Захват нажатия клавиш для записи хоткея через локальный `NSEvent` монитор.
@MainActor
final class HotkeyCaptureEngine: ObservableObject {
    @Published private(set) var isRecording = false

    private var recorder: HotkeyRecordingEventTap?

    var onCaptured: ((_ keyCode: Int, _ carbonModifiers: Int, _ fnGlobeHeld: Bool) -> Void)?
    var onEscape: (() -> Void)?

    deinit {
        recorder?.stop()
    }

    func start() {
        guard !isRecording else { return }
        isRecording = true

        let tap = HotkeyRecordingEventTap()
        tap.onEscape = { [weak self] in self?.handleEscape() }
        tap.onCapturedKeyDown = { [weak self] keyCode, carbon, fnHeld in
            self?.handleCapture(keyCode: keyCode, carbon: carbon, fnHeld: fnHeld)
        }
        if tap.start() {
            recorder = tap
        } else {
            isRecording = false
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        recorder?.stop()
        recorder = nil
    }

    private func handleCapture(keyCode: Int, carbon: Int, fnHeld: Bool) {
        onCaptured?(keyCode, carbon, fnHeld)
        stop()
    }

    private func handleEscape() {
        onEscape?()
        stop()
    }
}

struct HotkeyRecorderView: View {
    @Binding var hotkey: HotkeyConfig
    @EnvironmentObject private var localizer: LocalizationStore
    @StateObject private var engine = HotkeyCaptureEngine()
    @State private var isHovered = false

    var body: some View {
        RecorderFieldChrome(isRecording: engine.isRecording, isHovered: $isHovered, onTap: toggle) {
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: engine.isRecording ? "record.circle.fill" : "keyboard")
                    .font(DS.Typography.label)
                    .foregroundStyle(engine.isRecording ? DS.Colors.blueAccent : Color.secondary)
                    .accessibilityHidden(true)

                Text(engine.isRecording
                    ? localizer.text(.pressCombination)
                    : hotkey.displayString(language: localizer.language))
                    .font(DS.Typography.hotkeyDisplay())
                    .foregroundStyle(engine.isRecording ? DS.Colors.blueAccent : hotkey.isEmpty ? Color.secondary : Color.primary)
                    .lineLimit(1)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                if !engine.isRecording {
                    Spacer(minLength: 0)
                    if !hotkey.isEmpty {
                        FieldClearButton {
                            hotkey = .empty
                        }
                        .help(localizer.text(.reset))
                    }
                    Menu {
                        Section {
                            Button {
                                hotkey = HotkeyConfig(keyCode: KeyCodes.tab, carbonModifiers: CarbonModifiers.command)
                            } label: {
                                Label("⌘ Tab", systemImage: "arrow.left.arrow.right")
                            }
                            Button {
                                hotkey = HotkeyConfig(keyCode: KeyCodes.tab, carbonModifiers: CarbonModifiers.command | CarbonModifiers.shift)
                            } label: {
                                Label("⇧⌘ Tab", systemImage: "arrow.left.arrow.right")
                            }
                        }
                        Section {
                            ForEach(HotkeyConfig.functionKeyVirtualCodes, id: \.code) { entry in
                                Button(entry.label) {
                                    let mods = hotkey.isEmpty ? 0 : hotkey.carbonModifiers
                                    hotkey = HotkeyConfig(keyCode: entry.code, carbonModifiers: mods)
                                }
                            }
                        }
                    } label: {
                        SidebarAppMenuPickerChevronLabel()
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .iconOnlyHelp(localizer.text(.hotkeyPickerMenuHelp))
                }
            }
        }
        .onAppear(perform: configureEngine)
        .onDisappear(perform: engine.stop)
    }

    private func configureEngine() {
        engine.onCaptured = { keyCode, carbon, fnHeld in
            var newConfig = HotkeyConfig(keyCode: keyCode, carbonModifiers: carbon)
            if fnHeld, newConfig.carbonModifiers & HotkeyConfig.carbonFnModifierMask == 0 {
                newConfig.carbonModifiers |= HotkeyConfig.carbonFnModifierMask
            }
            if HotkeyConfig.arrowKeyVirtualCodes.contains(newConfig.keyCode), !fnHeld {
                newConfig.carbonModifiers &= ~HotkeyConfig.carbonFnModifierMask
            }
            hotkey = newConfig
        }
        engine.onEscape = { hotkey = .empty }
    }

    private func toggle() {
        if engine.isRecording { engine.stop() } else { engine.start() }
    }
}

struct KeystrokeRecorderView: View {
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    @EnvironmentObject private var localizer: LocalizationStore
    @StateObject private var engine = HotkeyCaptureEngine()
    @State private var isHovered = false

    private var isEmpty: Bool {
        keyCode == 0 && modifiers == 0
    }

    var body: some View {
        RecorderFieldChrome(isRecording: engine.isRecording, isHovered: $isHovered, onTap: toggle) {
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: engine.isRecording ? "record.circle.fill" : "command")
                    .font(DS.Typography.label)
                    .foregroundStyle(engine.isRecording ? DS.Colors.blueAccent : Color.secondary)

                Text(engine.isRecording
                    ? localizer.text(.pressCombination)
                    : HotkeyConfig.keystrokeDisplayString(
                        keyCode: keyCode,
                        modifiers: modifiers,
                        language: localizer.language
                    ))
                    .font(DS.Typography.hotkeyDisplay())
                    .foregroundStyle(engine.isRecording ? DS.Colors.blueAccent : isEmpty ? Color.secondary : Color.primary)
                    .lineLimit(1)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear(perform: configureEngine)
        .onDisappear(perform: engine.stop)
    }

    private func configureEngine() {
        engine.onCaptured = { recordedKeyCode, carbon, fnHeld in
            var adjusted = carbon
            if HotkeyConfig.arrowKeyVirtualCodes.contains(recordedKeyCode), !fnHeld {
                adjusted &= ~HotkeyConfig.carbonFnModifierMask
            }
            if fnHeld, adjusted & HotkeyConfig.carbonFnModifierMask == 0 {
                adjusted |= HotkeyConfig.carbonFnModifierMask
            }
            let normalized = HotkeyConfig.normalizedKeystrokeFromRecording(
                keyCode: recordedKeyCode,
                carbonModifiers: adjusted,
                fnGlobeHeld: fnHeld
            )
            keyCode = normalized.keyCode
            modifiers = normalized.cgModifiers
        }
        engine.onEscape = {}
    }

    private func toggle() {
        if engine.isRecording { engine.stop() } else { engine.start() }
    }
}

extension HotkeyConfig {
    init(from event: NSEvent) {
        self.keyCode = Int(event.keyCode)
        self.carbonModifiers = CarbonModifiers.carbon(from: event.modifierFlags)
    }

    /// Оставлено для совместимости: делегирует к `CarbonModifiers`.
    static func carbonModifiersFromNS(_ flags: NSEvent.ModifierFlags) -> Int {
        CarbonModifiers.carbon(from: flags)
    }
}
