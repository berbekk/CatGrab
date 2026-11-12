import XCTest
@testable import CatGrabLib

final class NativeAppSwitcherTests: XCTestCase {
    func test_doesNotRestoreAShortcutAlreadyDisabledByAnotherUtility() {
        var state = SymbolicHotkeyOwnership()
        var enabled: Set<Int32> = [1]
        var writes: [Int32] = []
        let write: (Int32, Bool) -> Bool = { key, value in
            writes.append(key)
            if value { enabled.insert(key) } else { enabled.remove(key) }
            return true
        }
        state.update(wanted: [1, 2], isEnabled: { enabled.contains($0) }, setEnabled: write)
        XCTAssertEqual(enabled, [])
        state.update(wanted: [], isEnabled: { enabled.contains($0) }, setEnabled: write)
        XCTAssertEqual(enabled, [1])
        XCTAssertEqual(writes, [1, 1])
    }

    func test_failedDisableDoesNotCreateOwnershipAndFailedRestoreCanRetry() {
        var state = SymbolicHotkeyOwnership()
        state.update(wanted: [1], isEnabled: { _ in true }, setEnabled: { _, _ in false })
        XCTAssertTrue(state.disabledKeys.isEmpty)
        state.update(wanted: [1], isEnabled: { _ in true }, setEnabled: { _, _ in true })
        state.update(wanted: [], isEnabled: { _ in false }, setEnabled: { _, _ in false })
        XCTAssertEqual(state.disabledKeys, [1])
        state.update(wanted: [], isEnabled: { _ in false }, setEnabled: { _, _ in true })
        XCTAssertTrue(state.disabledKeys.isEmpty)
    }
}
