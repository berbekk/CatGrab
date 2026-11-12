import Foundation
import Combine

@MainActor
final class HotkeyAvailability: ObservableObject {
    static let shared = HotkeyAvailability()
    @Published var unavailableMenuIDs: Set<UUID> = []
}

/// Пара нажатие/отпускание принадлежит одному хоткею, даже если модификаторы уже отпущены.
struct HotkeyInputState {
    enum Action: Equatable {
        case passThrough
        case consume
        case pressed([UInt32])
        case released([UInt32])
    }

    private var heldKeys: [Int: [UInt32]] = [:]
    private var heldFn: [UInt32]?

    mutating func key(keyCode: Int, isDown: Bool, isRepeat: Bool, matching indices: [UInt32]?) -> Action {
        if !isDown {
            guard let held = heldKeys.removeValue(forKey: keyCode) else { return .passThrough }
            return .released(held)
        }
        if heldKeys[keyCode] != nil { return .consume }
        guard let indices, !indices.isEmpty else { return .passThrough }
        // Не открываем меню посреди удержания клавиши после переподключения tap.
        guard !isRepeat else { return .passThrough }
        heldKeys[keyCode] = indices
        return .pressed(indices)
    }

    mutating func fn(keyCode: Int, isDown: Bool, hasOtherModifiers: Bool, indices: [UInt32]) -> Action {
        // Стрелки и F-клавиши тоже несут secondaryFn. Это не физическая Fn/Globe.
        guard keyCode == HotkeyConfig.fnKeyVirtualCode else { return .passThrough }
        if !isDown {
            guard let held = heldFn else { return .passThrough }
            heldFn = nil
            return .released(held)
        }
        if heldFn != nil { return .consume }
        guard !hasOtherModifiers, !indices.isEmpty else { return .passThrough }
        heldFn = indices
        return .pressed(indices)
    }
}

/// Только параметры, влияющие на регистрацию. Цвета и содержимое меню tap не перезапускают.
struct HotkeyRegistration: Equatable {
    let menuID: UUID
    let hotkey: HotkeyConfig

    static func bindings(for menus: [PieMenu]) -> [Self] {
        menus.map {
            Self(menuID: $0.id, hotkey: $0.isDynamicMenu && !$0.runningAppsMenuEnabled ? .empty : $0.hotkey)
        }
    }
}
