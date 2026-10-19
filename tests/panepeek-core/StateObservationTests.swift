import Observation
import Testing

@MainActor struct StateObservationTests {
    @Observable final class State { var count = 0 }

    @Test func followsChangesUntilTheRequiredState() async throws {
        let state = State()
        let (observations, observed) = AsyncStream<Int>.makeStream()
        let waiting = Task {
            defer { observed.finish() }
            try await waitForState { observed.yield(state.count); return state.count == 2 }
        }
        for await count in observations {
            if count == 0 { state.count = 1 }
            if count == 1 { state.count = 2 }
        }
        try await waiting.value
        #expect(state.count == 2)
        try await waitForState(timeout: .zero) { state.count == 2 }
    }

    @Test func missingChangesReportTimeoutAndCancellationWakesTheWaiter() async throws {
        try await withKnownIssue {
            try await waitForState(timeout: .zero) { false }
        } matching: { $0.description.contains("Timed out waiting for observable state") }
        let (observations, started) = AsyncStream<Void>.makeStream()
        let waiting = Task {
            try await waitForState { started.finish(); return false }
        }
        for await _ in observations { }
        waiting.cancel()
        await #expect(throws: CancellationError.self) { try await waiting.value }
    }
}
