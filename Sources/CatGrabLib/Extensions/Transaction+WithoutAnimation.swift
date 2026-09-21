import SwiftUI

/// Выполняет изменения состояния без SwiftUI-анимации, даже если во внешнем
/// дереве активна `.animation(_:value:)`, которая иначе подхватила бы эти изменения.
@inlinable
func withoutAnimation<Result>(_ body: () -> Result) -> Result {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    return withTransaction(transaction, body)
}
