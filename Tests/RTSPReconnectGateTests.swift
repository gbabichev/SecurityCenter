import Foundation

@MainActor
private final class PlaybackHarness {
    let source = URL(string: "rtsp://192.0.2.1/live")!
    var gate = RTSPReconnectGate()
    var mediaReplacements = 0
    var queued: CheckedContinuation<Void, Never>?

    func enqueue(_ ticket: RTSPReconnectGate.Ticket) -> Task<Void, Never> {
        Task { @MainActor in
            // Simulate the original race: preflight succeeds, then execution waits on the actor.
            guard !Task.isCancelled else { return }
            await withCheckedContinuation { queued = $0 }
            if gate.consume(ticket, currentURL: source, isActive: true, isCancelled: Task.isCancelled) {
                mediaReplacements += 1
            }
        }
    }

    func waitUntilQueued() async {
        while queued == nil { await Task.yield() }
    }

    func releaseQueued() {
        let continuation = queued
        queued = nil
        continuation?.resume()
    }
}

@main
struct RTSPReconnectGateTests {
    @MainActor
    static func main() async {
        let harness = PlaybackHarness()
        let ticket = harness.gate.begin(for: harness.source)
        let cancelled = harness.enqueue(ticket)
        await harness.waitUntilQueued()
        cancelled.cancel() // Cancel after preflight and before the media mutation.
        harness.releaseQueued()
        await cancelled.value
        precondition(harness.mediaReplacements == 0, "Cancelled queued retry replaced media")

        let recoveredTicket = harness.gate.begin(for: harness.source)
        let recovered = harness.enqueue(recoveredTicket)
        await harness.waitUntilQueued()
        harness.gate.cancel() // Playback recovered before the retry could run.
        harness.releaseQueued()
        await recovered.value
        precondition(harness.mediaReplacements == 0, "Recovered playback was restarted")

        let oldTicket = harness.gate.begin(for: harness.source)
        let stale = harness.enqueue(oldTicket)
        await harness.waitUntilQueued()
        let latestTicket = harness.gate.begin(for: harness.source)
        harness.releaseQueued()
        await stale.value
        precondition(harness.mediaReplacements == 0, "Superseded retry replaced media")
        precondition(harness.gate.consume(latestTicket, currentURL: harness.source, isActive: true, isCancelled: false))
        precondition(!harness.gate.consume(latestTicket, currentURL: harness.source, isActive: true, isCancelled: false), "Retry executed twice")

        let changedSource = harness.gate.begin(for: harness.source)
        precondition(!harness.gate.consume(changedSource, currentURL: URL(string: "rtsp://192.0.2.2/live"), isActive: true, isCancelled: false))
        let stopped = harness.gate.begin(for: harness.source)
        precondition(!harness.gate.consume(stopped, currentURL: harness.source, isActive: false, isCancelled: false))

        let validTicket = harness.gate.begin(for: harness.source)
        let valid = harness.enqueue(validTicket)
        await harness.waitUntilQueued()
        harness.releaseQueued()
        await valid.value
        precondition(harness.mediaReplacements == 1, "Current retry must still recover playback")
        print("PASS: cancellation after preflight, recovery, superseded retries, source changes, stopped playback, one-use tickets, and valid retries")
    }
}
