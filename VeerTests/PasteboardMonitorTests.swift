import AppKit
import Foundation
import Testing
@testable import Veer

@MainActor
struct PasteboardMonitorTests {
    private func makeMonitor() -> (PasteboardMonitor, MockPasteboardSource, MockFrontmostAppProvider) {
        let source = MockPasteboardSource()
        let frontmost = MockFrontmostAppProvider()
        let monitor = PasteboardMonitor(source: source, frontmost: frontmost, interval: .milliseconds(1))
        return (monitor, source, frontmost)
    }

    @Test func pollEmitsEventOnNewChangeCount() async throws {
        let (monitor, source, frontmost) = makeMonitor()
        frontmost.bundleId = "com.test.app"
        var iterator = monitor.events.makeAsyncIterator()

        source.push([NSPasteboard.PasteboardType.string.rawValue: Data("hi".utf8)])
        monitor.poll()

        let event = await iterator.next()
        #expect(event?.payload.typed[NSPasteboard.PasteboardType.string.rawValue] == Data("hi".utf8))
        #expect(event?.sourceBundleId == "com.test.app")
    }

    @Test func pollIgnoresStaleChangeCount() async {
        let (monitor, source, _) = makeMonitor()
        source.push([NSPasteboard.PasteboardType.string.rawValue: Data("a".utf8)])
        monitor.poll()
        let countAfterFirst = source.snapshotCallCount

        monitor.poll()
        #expect(source.snapshotCallCount == countAfterFirst)
    }

    @Test func pollSkipsEmptySnapshots() {
        let source = MockPasteboardSource()
        let frontmost = MockFrontmostAppProvider()
        let monitor = PasteboardMonitor(source: source, frontmost: frontmost, interval: .milliseconds(1))

        source.changeCount = 99
        source.snapshots = [PasteboardItemSnapshot(typed: [:])]
        monitor.poll()

        #expect(source.snapshotCallCount == 1)
    }

    @Test func emptySnapshotDoesNotAdvancePastClipUntilDataArrives() async throws {
        // Simulates the clearContents/setData race: changeCount bumps first, data populates
        // a few polls later. Veer must retry rather than advance lastChangeCount past the clip.
        let source = MockPasteboardSource()
        let frontmost = MockFrontmostAppProvider()
        let monitor = PasteboardMonitor(source: source, frontmost: frontmost, interval: .milliseconds(1))

        source.changeCount = 42
        source.snapshots = [PasteboardItemSnapshot(typed: [:])]
        monitor.poll()
        monitor.poll()

        source.snapshots = [PasteboardItemSnapshot(typed: [NSPasteboard.PasteboardType.string.rawValue: Data("late".utf8)])]
        var iterator = monitor.events.makeAsyncIterator()
        monitor.poll()

        let event = await iterator.next()
        #expect(event?.payload.typed[NSPasteboard.PasteboardType.string.rawValue] == Data("late".utf8))
    }

    @Test func emptySnapshotRetriesAreBoundedAndAdvanceEventually() {
        let source = MockPasteboardSource()
        let frontmost = MockFrontmostAppProvider()
        let monitor = PasteboardMonitor(source: source, frontmost: frontmost, interval: .milliseconds(1))

        source.changeCount = 1
        source.snapshots = [PasteboardItemSnapshot(typed: [:])]
        // Burn through the retry budget without data ever arriving.
        for _ in 0..<6 { monitor.poll() }

        // After giving up, a fresh changeCount with real data still fires.
        source.push([NSPasteboard.PasteboardType.string.rawValue: Data("ok".utf8)])
        let priorCalls = source.snapshotCallCount
        monitor.poll()
        #expect(source.snapshotCallCount == priorCalls + 1)
    }

    @Test func emitsEventPerSnapshotItem() async throws {
        let source = MockPasteboardSource()
        let frontmost = MockFrontmostAppProvider()
        let monitor = PasteboardMonitor(source: source, frontmost: frontmost, interval: .milliseconds(1))

        source.changeCount = 1
        source.snapshots = [
            PasteboardItemSnapshot(typed: [NSPasteboard.PasteboardType.string.rawValue: Data("x".utf8)]),
            PasteboardItemSnapshot(typed: [NSPasteboard.PasteboardType.string.rawValue: Data("y".utf8)]),
        ]
        monitor.poll()

        var iterator = monitor.events.makeAsyncIterator()
        let first = await iterator.next()
        let second = await iterator.next()
        #expect(first?.payload.typed[NSPasteboard.PasteboardType.string.rawValue] == Data("x".utf8))
        #expect(second?.payload.typed[NSPasteboard.PasteboardType.string.rawValue] == Data("y".utf8))
    }

    @Test func acknowledgeSuppressesNextPollOfSameChangeCount() async {
        let (monitor, source, _) = makeMonitor()
        source.changeCount = 7
        source.snapshots = [PasteboardItemSnapshot(typed: [NSPasteboard.PasteboardType.string.rawValue: Data("self-write".utf8)])]

        // Caller acknowledges the change before the next poll — simulates a self-write.
        monitor.acknowledge(changeCount: 7)
        monitor.poll()

        #expect(source.snapshotCallCount == 0)
    }

    @Test func acknowledgeAllowsLaterUserChange() async throws {
        let source = MockPasteboardSource()
        let frontmost = MockFrontmostAppProvider()
        let monitor = PasteboardMonitor(source: source, frontmost: frontmost, interval: .milliseconds(1))
        source.changeCount = 7
        monitor.acknowledge(changeCount: 7)

        // Now the user copies something new — changeCount advances.
        source.push([NSPasteboard.PasteboardType.string.rawValue: Data("user".utf8)])
        var iterator = monitor.events.makeAsyncIterator()
        monitor.poll()
        let event = await iterator.next()
        #expect(event?.payload.typed[NSPasteboard.PasteboardType.string.rawValue] == Data("user".utf8))
    }

    @Test func startKicksOffPollingLoop() async throws {
        let (monitor, source, _) = makeMonitor()
        source.changeCount = 5
        source.snapshots = [PasteboardItemSnapshot(typed: [NSPasteboard.PasteboardType.string.rawValue: Data("z".utf8)])]
        monitor.start()
        defer { monitor.stop() }

        var iterator = monitor.events.makeAsyncIterator()
        let event = await iterator.next()
        #expect(event?.payload.typed[NSPasteboard.PasteboardType.string.rawValue] == Data("z".utf8))
    }
}
