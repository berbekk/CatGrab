import CoreGraphics
import AppKit

/// Единые биты Carbon-модификаторов и константы клавиш, чтобы не дублировать их по коду.
enum CarbonModifiers {
    /// Carbon-биты из `<Carbon/Events.h>`: command/shift/option/control.
    static let command  = 256
    static let shift    = 512
    static let option   = 2048
    static let control  = 4096

    /// Carbon `kEventKeyModifierFnMask` для F1–F12 с клавишей Fn (используется и как флаг Globe/Fn в нашем формате).
    static let fn = HotkeyConfig.carbonFnModifierMask

    /// `CGEventFlags` → набор Carbon-битов.
    static func carbon(from flags: CGEventFlags) -> Int {
        var carbon = 0
        if flags.contains(.maskCommand) { carbon |= command }
        if flags.contains(.maskShift) { carbon |= shift }
        if flags.contains(.maskAlternate) { carbon |= option }
        if flags.contains(.maskControl) { carbon |= control }
        if flags.contains(.maskSecondaryFn) { carbon |= fn }
        return carbon
    }

    /// `NSEvent.ModifierFlags` → набор Carbon-битов (device-independent).
    static func carbon(from flags: NSEvent.ModifierFlags) -> Int {
        let f = flags.intersection(.deviceIndependentFlagsMask)
        var carbon = 0
        if f.contains(.command) { carbon |= command }
        if f.contains(.shift) { carbon |= shift }
        if f.contains(.option) { carbon |= option }
        if f.contains(.control) { carbon |= control }
        if f.contains(.function) { carbon |= fn }
        return carbon
    }
}

/// Имена часто используемых virtual key codes из `<HIToolbox/Events.h>`.
enum KeyCodes {
    static let escape       = 53
    static let tab          = 48
    static let space        = 49
    static let returnKey    = 36
    static let delete       = 51

    static let leftArrow    = 123
    static let rightArrow   = 124
    static let downArrow    = 125
    static let upArrow      = 126

    static let home         = 115
    static let end          = 119
    static let pageUp       = 116
    static let pageDown     = 121

    /// Стрелки направлений (для нормализации Fn+клавиша навигации).
    static let arrowKeys: Set<Int> = [leftArrow, rightArrow, downArrow, upArrow]
}
