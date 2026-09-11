import AppKit
import SwiftUI

/// SwiftUI `Toggle` со стилем switch на macOS даёт широкую зону hit-testing и перехватывает клики по всей строке сайдбара.
/// Здесь только сам `NSSwitch` получает события; остальная площадь колонки «прозрачна» для слоёв ниже.
struct RunningAppsMenuEnabledSwitch: NSViewRepresentable {
    @Binding var isOn: Bool

    final class SwitchColumnView: NSView {
        let sw = NSSwitch()
        var onStateChange: ((Bool) -> Void)?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            sw.target = self
            sw.action = #selector(switchChanged)
            addSubview(sw)
        }

        required init?(coder: NSCoder) {
            nil
        }

        @objc private func switchChanged() {
            onStateChange?(sw.state == .on)
        }

        override var intrinsicContentSize: NSSize {
            sw.sizeToFit()
            let w = max(sw.frame.width, 26)
            let h = max(sw.frame.height, 16)
            return NSSize(width: w, height: h)
        }

        override func layout() {
            super.layout()
            sw.sizeToFit()
            let w = sw.frame.width
            let h = sw.frame.height
            sw.frame = NSRect(
                x: bounds.maxX - w,
                y: max(0, (bounds.height - h) / 2),
                width: w,
                height: h
            )
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard bounds.contains(point) else { return nil }
            let inSwitch = convert(point, to: sw)
            guard sw.bounds.contains(inSwitch) else { return nil }
            return sw.hitTest(inSwitch)
        }
    }

    final class Coordinator {
        var isOn: Binding<Bool>
        init(isOn: Binding<Bool>) {
            self.isOn = isOn
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isOn: $isOn)
    }

    func makeNSView(context: Context) -> SwitchColumnView {
        let v = SwitchColumnView()
        v.sw.state = isOn ? .on : .off
        v.onStateChange = { [c = context.coordinator] newVal in
            c.isOn.wrappedValue = newVal
        }
        return v
    }

    func updateNSView(_ nsView: SwitchColumnView, context: Context) {
        nsView.onStateChange = { [c = context.coordinator] newVal in
            c.isOn.wrappedValue = newVal
        }
        let target: NSControl.StateValue = isOn ? .on : .off
        if nsView.sw.state != target {
            nsView.sw.state = target
        }
    }
}
