import Synchronization

/// Gives concurrent test observers shared ownership of one locked value.
final class TestSharedState<Value: Sendable>: Sendable {
    let value: Mutex<Value>

    init(_ initialValue: Value) {
        value = Mutex(initialValue)
    }
}
