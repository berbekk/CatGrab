import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var configObserver: NSObjectProtocol?
    private var clickOutsideMonitor: Any?
    /// После первого показа окна SwiftUI назначает первым респондером первый `NSTextField` и выделяет текст — снимаем фокус один раз.
    private var clearedInitialFieldFocus = false
    private let screenInset: CGFloat = 48

    deinit {
        if let clickOutsideMonitor {
            NSEvent.removeMonitor(clickOutsideMonitor)
        }
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
        }
    }

    func show() {
        if window == nil {
            createWindow()
        }
        bringToFront()
        DispatchQueue.main.async { [weak self] in
            self?.bringToFront()
        }
    }

    private func createWindow() {
        clearedInitialFieldFocus = false

        let settingsView = SettingsView()
            .environmentObject(LocalizationStore.shared)
        let hostingView = NSHostingView(rootView: settingsView)

        let fixed = targetContentSize(for: NSScreen.main)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: fixed),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = localizedWindowTitle()
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.contentView = hostingView
        window.contentMinSize = fixed
        window.contentMaxSize = fixed
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.delegate = self
        window.isMovableByWindowBackground = false
        window.backgroundColor = NSColor.windowBackgroundColor
        window.setFrameAutosaveName("SettingsWindow")
        enforceFixedContentSize(window)
        if !isFrameVisibleOnAnyScreen(window.frame) {
            window.center()
        }

        self.window = window

        configObserver = NotificationCenter.default.addObserver(
            forName: .configurationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.window?.title = self?.localizedWindowTitle() ?? ""
            }
        }

        installClickOutsideMonitor()
    }

    private func bringToFront() {
        guard let window else { return }
        window.deminiaturize(nil)
        enforceFixedContentSize(window)
        if !isFrameVisibleOnAnyScreen(window.frame) {
            window.center()
        }
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Снимает фокус с текстового поля при клике по любой области окна настроек,
    /// которая не является полем ввода. Покрывает как AppKit, так и SwiftUI `TextField`.
    private func installClickOutsideMonitor() {
        guard clickOutsideMonitor == nil else { return }
        clickOutsideMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let window = self.window, event.window === window else { return event }
            guard let hitView = self.currentEditingHitView() else { return event }
            let pointInView = hitView.convert(event.locationInWindow, from: nil)
            if hitView.bounds.contains(pointInView) { return event }
            window.makeFirstResponder(nil)
            return event
        }
    }

    /// Возвращает область экрана, внутри которой клики не должны снимать фокус.
    /// Для AppKit полей — сам `NSTextField`; для `NSTextView` — скролл-контейнер или сам view.
    private func currentEditingHitView() -> NSView? {
        guard let responder = window?.firstResponder else { return nil }
        if let textView = responder as? NSTextView {
            if textView.isFieldEditor, let field = textView.delegate as? NSView {
                return field
            }
            return textView.enclosingScrollView ?? textView
        }
        return nil
    }

    private func enforceFixedContentSize(_ w: NSWindow) {
        let target = targetContentSize(for: w.screen ?? NSScreen.main)
        w.contentMinSize = target
        w.contentMaxSize = target
        let content = w.contentRect(forFrameRect: w.frame).size
        guard content.width != target.width || content.height != target.height else { return }
        w.setContentSize(target)
    }

    private func targetContentSize(for screen: NSScreen?) -> NSSize {
        let preferred = NSSize(
            width: DS.SettingsWindow.contentWidth,
            height: DS.SettingsWindow.contentHeight
        )
        guard let screen else { return preferred }
        let visible = screen.visibleFrame.size
        let maxWidth = max(DS.SettingsWindow.minimumContentWidth, visible.width - screenInset * 2)
        let maxHeight = max(DS.SettingsWindow.minimumContentHeight, visible.height - screenInset * 2)
        return NSSize(
            width: min(preferred.width, maxWidth),
            height: min(preferred.height, maxHeight)
        )
    }

    private func isFrameVisibleOnAnyScreen(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { screen in
            screen.visibleFrame.intersection(frame).width > 80
                && screen.visibleFrame.intersection(frame).height > 80
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard let w = notification.object as? NSWindow,
              w === window,
              !clearedInitialFieldFocus
        else { return }
        clearedInitialFieldFocus = true
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                w.makeFirstResponder(nil)
            }
        }
    }

    /// Не закрываем окно (иначе при LSUIElement приложение часто завершается вместе с последним окном).
    /// Скрываем и возвращаемся в режим accessory — приложение остаётся в статус-баре.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === window else { return true }
        sender.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        return false
    }

    private func localizedWindowTitle() -> String {
        LocalizationStore.shared.text(.settingsWindowTitle)
    }
}
