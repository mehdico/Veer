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

    private func imageEvent() -> MonitorEvent {
        MonitorEvent(
            payload: ClipPayload(typed: [NSPasteboard.PasteboardType.png.rawValue: Data([0x89, 0x50])]),
            sourceBundleId: nil
        )
    }

    private func fileEvent() -> MonitorEvent {
        MonitorEvent(
            payload: ClipPayload(typed: [NSPasteboard.PasteboardType.fileURL.rawValue: Data("file:///tmp/a.txt".utf8)]),
            sourceBundleId: nil
        )
    }

    private func richTextEvent() -> MonitorEvent {
        MonitorEvent(
            payload: ClipPayload(typed: [NSPasteboard.PasteboardType.rtf.rawValue: Data("rtf".utf8)]),
            sourceBundleId: nil
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

    @Test func textOnlyModeRejectsImagesAndFiles() {
        let repo = MockClipRepository()
        let monitor = StubMonitor()
        let ingestor = ClipIngestor(monitor: monitor, repository: repo, textOnlyHistory: { true })

        #expect(ingestor.ingest(imageEvent()) == .rejectedNonText)
        #expect(ingestor.ingest(fileEvent()) == .rejectedNonText)
        #expect(repo.inserted.isEmpty)
    }

    @Test func textOnlyModeStillStoresTextAndRichText() {
        let repo = MockClipRepository()
        let monitor = StubMonitor()
        let ingestor = ClipIngestor(monitor: monitor, repository: repo, textOnlyHistory: { true })

        if case .inserted = ingestor.ingest(textEvent("hello")) {} else {
            Issue.record("Expected text to be inserted")
        }
        if case .inserted = ingestor.ingest(richTextEvent()) {} else {
            Issue.record("Expected rich text to be inserted")
        }
        #expect(repo.inserted.count == 2)
    }

    @Test func defaultPolicyStoresImages() {
        let repo = MockClipRepository()
        let monitor = StubMonitor()
        let ingestor = ClipIngestor(monitor: monitor, repository: repo)

        if case .inserted = ingestor.ingest(imageEvent()) {} else {
            Issue.record("Expected image to be inserted")
        }
        #expect(repo.inserted.count == 1)
    }

    @Test func textOnlyModeSkipsNonTextEventsFromStream() async throws {
        let repo = MockClipRepository()
        let monitor = StubMonitor()
        let ingestor = ClipIngestor(monitor: monitor, repository: repo, textOnlyHistory: { true })

        ingestor.start()
        monitor.push(imageEvent())
        monitor.push(textEvent("kept"))

        let deadline = Date().addingTimeInterval(10)
        while repo.inserted.count < 1 && Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(repo.inserted.count == 1)
        #expect(repo.inserted.first?.payload.plainTextPreview() == "kept")

        ingestor.stop()
    }
}
