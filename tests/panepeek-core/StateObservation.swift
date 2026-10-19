import Foundation
import Observation
import Testing

/// Await observable state changes; the deadline only guards against a stalled test.
@MainActor func waitForState(timeout: Duration = .seconds(30),
                             sourceLocation: SourceLocation = #_sourceLocation,
                             _ completed: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while !completed() {
        try Task.checkCancellation()
        let (changes, continuation) = AsyncStream<Void>.makeStream()
        withObservationTracking { _ = completed() } onChange: { continuation.finish() }
        let timer = Task {
            do { try await Task.sleep(until: deadline) } catch { return }
            continuation.finish()
        }
        defer { timer.cancel() }
        for await _ in changes { }
        try Task.checkCancellation()
        try #require(completed() || ContinuousClock.now < deadline,
                     "Timed out waiting for observable state", sourceLocation: sourceLocation)
    }
}
