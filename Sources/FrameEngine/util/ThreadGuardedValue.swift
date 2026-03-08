import Common

package final class ThreadGuardedValue<Value>: Sendable {
    nonisolated(unsafe) private var _threadGuarded: Value?
    private let threadToken: AxAppThreadToken = axTaskLocalAppThreadToken ?? dieT("axTaskLocalAppThreadToken is not initialized")
    package init(_ value: Value) { self._threadGuarded = value }
    package var threadGuarded: Value {
        get {
            threadToken.checkEquals(axTaskLocalAppThreadToken)
            return _threadGuarded ?? dieT("Value is already destroyed")
        }
        set(newValue) {
            threadToken.checkEquals(axTaskLocalAppThreadToken)
            _threadGuarded = newValue
        }
    }
    package func destroy() {
        threadToken.checkEquals(axTaskLocalAppThreadToken)
        _threadGuarded = nil
    }
    deinit {
        check(_threadGuarded == nil, "The Value must be explicitly destroyed on the appropriate thread before deinit")
    }
}
