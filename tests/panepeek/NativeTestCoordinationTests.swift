import Testing

@Suite(.serialized) @MainActor struct NativeTestCoordinationTests {
    @Test(arguments: [false, true])
    func missingEventReportsItsLocalDeadline(providerStarted: Bool) async {
        let expected = NativeTestTimeout(event: "missing updater callback \(providerStarted ? "result" : "start")")
        var finished = false
        await withKnownIssue {
            await #expect(throws: expected) {
                try await withNativeTestScope(timeout: .milliseconds(20)) { scope in
                    // This outer bound also catches a broken local deadline.
                    let watchdog = Task {
                        try await Task.sleep(for: .seconds(1))
                        scope.close()
                    }
                    defer { watchdog.cancel() }
                    let request: NativeTestRequest<Void> = scope.request("missing updater callback")
                    if providerStarted {
                        let worker = Task {
                            defer { finished = true }
                            try await request.value()
                        }
                        scope.track(worker)
                        try await request.started.wait()
                        try await worker.value
                    } else {
                        try await request.started.wait()
                    }
                }
            }
        } matching: { $0.error as? NativeTestTimeout == expected }
        #expect(finished == providerStarted)
    }

    @Test(arguments: [false, true])
    func earlyFailureReleasesAndJoinsTheProvider(afterRegistration: Bool) async {
        struct EarlyFailure: Error {}
        var finished = false
        await #expect(throws: EarlyFailure.self) {
            try await withNativeTestScope { scope in
                let request: NativeTestRequest<Void> = scope.request("abandoned updater check")
                let worker = Task {
                    defer { finished = true }
                    try await request.value()
                }
                scope.track(worker)
                if afterRegistration { try await request.started.wait() }
                throw EarlyFailure()
            }
        }
        #expect(finished)
    }

    @Test func cancellationReleasesAndJoinsTheProvider() async throws {
        let started = NativeTestEvent<Void>("cancellation fixture start", timeout: .seconds(5))
        var finished = false
        let parent = Task {
            try await withNativeTestScope { scope in
                let request: NativeTestRequest<Void> = scope.request("cancelled updater check")
                let worker = Task {
                    defer { finished = true }
                    try await request.value()
                }
                scope.track(worker)
                try await request.started.wait()
                started.signal(())
                let pending: NativeTestEvent<Void> = scope.event("cancelled test body")
                try await pending.wait()
            }
        }
        defer { parent.cancel() }
        try await started.wait()
        parent.cancel()
        await #expect(throws: CancellationError.self) { try await parent.value }
        #expect(finished)
    }
}
