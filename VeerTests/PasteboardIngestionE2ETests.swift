import Foundation
import XCTest
@testable import Veer

@MainActor
final class PasteboardIngestionE2ETests: XCTestCase {
    @MainActor
    private final class FakePasteboardSource: PasteboardSource {
        var changeCount: Int = 0
        var nextSnapshot: [PasteboardItemSnapshot] = []
        func snapshot() -> [PasteboardItemSnapshot] { nextSnapshot }
    }

    @MainActor
    private final class FakeFrontmost: FrontmostAppProviding {
        var bundleId: String? = nil
        func currentBundleId() -> String? { bundleId }
    }

    func test_monitorRetriesUntilPasteboardDataAvailable_withoutFurtherChangeCount() async throws {
        let source = FakePasteboardSource()
        let frontmost = FakeFrontmost()
        let monitor = PasteboardMonitor(source: source, frontmost: frontmost, interval: .milliseconds(10))

        let gotEvent = expectation(description: "received monitor event")
        var received: MonitorEvent?

        let consumer = Task { @MainActor in
            var it = monitor.events.makeAsyncIterator()
            received = await it.next()
            gotEvent.fulfill()
        }

        source.changeCount = 1
        source.nextSnapshot = [PasteboardItemSnapshot(typed: [:])]

        for _ in 0..<15 {
            monitor.poll()
            try await Task.sleep(for: .milliseconds(10))
        }

        let payload = ClipPayload(typed: ["public.utf8-plain-text": Data("hello".utf8)])
        source.nextSnapshot = [PasteboardItemSnapshot(typed: payload.typed)]

        for _ in 0..<50 {
            monitor.poll()
            if received != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        await fulfillment(of: [gotEvent], timeout: 2.0)
        consumer.cancel()

        XCTAssertEqual(received?.payload, payload)
        XCTAssertNil(received?.sourceBundleId)
    }
}

