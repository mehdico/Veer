import AppKit
import Foundation
import Testing
@testable import Veer

@MainActor
struct ClipIngestorTests {
    @MainActor
    final class StubMonitor: PasteboardMonitoring {
        let continuation: AsyncStream<MonitorEvent>.Continuation
        let events: AsyncStream<MonitorEvent>
        var startCalls = 0
        var stopCalls = 0

        init() {
            var continuation: AsyncStream<MonitorEvent>.Continuation!
            self.events = AsyncStream { continuation = $0 }
            self.continuation = continuation
        }

        func start() { startCalls += 1 }
        func stop() { stopCalls += 1 }
        func poll() {}
        func acknowledge(changeCount: Int) {}
        func push(_ event: MonitorEvent) { continuation.yield(event) }
    }

    private func textEvent(_ s: String, bundle: String? = nil) -> MonitorEvent {
        MonitorEvent(
            payload: ClipPayload(typed: [NSPasteboard.PasteboardType.string.rawValue: Data(s.utf8)]),
            sourceBundleId: bundle
        )
    }

    @Test func ingestForwardsToRepository() throws {
        let repo = MockClipRepository()
        let monitor = StubMonitor()
        let ingestor = ClipIngestor(monitor: monitor, repository: repo)

        let event = textEvent("hi", bundle: "com.test")
        let outcome = ingestor.ingest(event)
        if case .inserted = outcome {} else { Issue.record("Expected inserted"); return }
        #expect(repo.inserted.count == 1)
        #expect(repo.inserted.first?.sourceBundleId == "com.test")
    }

    @Test func ingestReturnsRepositoryOutcome() {
        let repo = MockClipRepository()
        repo.nextOutcome = .rejectedDuplicate
        let monitor = StubMonitor()
        let ingestor = ClipIngestor(monitor: monitor, repository: repo)

        #expect(ingestor.ingest(textEvent("dup")) == .rejectedDuplicate)
    }

    @Test func ingestSwallowsRepositoryErrors() {
        struct Boom: Error {}
        let repo = MockClipRepository()
        repo.insertError = Boom()
        let monitor = StubMonitor()
        let ingestor = ClipIngestor(monitor: monitor, repository: repo)

        #expect(ingestor.ingest(textEvent("x")) == .rejectedEmpty)
    }

    @Test func startWiresMonitorStreamIntoRepository() async throws {
        let repo = MockClipRepository()
        let monitor = StubMonitor()
        let ingestor = ClipIngestor(monitor: monitor, repository: repo)

        ingestor.start()
        #expect(monitor.startCalls == 1)

        monitor.push(textEvent("first"))

        let deadline = Date().addingTimeInterval(10)
        while repo.inserted.isEmpty && Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(repo.inserted.count == 1)

        ingestor.stop()
        #expect(monitor.stopCalls == 1)
    }
}
