import AppKit
import Foundation
import Testing
@testable import Veer

@MainActor
struct RepositoryPerformanceTests {
    @Test func insertOneThousandTextItemsCompletesUnderCeiling() throws {
        let container = try VeerStore.inMemory()
        let repo = ClipRepositoryLive(container: container, maxItems: 5_000)

        let count = 1_000
        let start = Date()
        for i in 0..<count {
            let payload = ClipPayload(typed: [
                NSPasteboard.PasteboardType.string.rawValue: Data("perf-item-\(i)".utf8),
            ])
            _ = try repo.insert(payload: payload, sourceBundleId: nil)
        }
        let elapsed = Date().timeIntervalSince(start)
        let perInsertMs = (elapsed / Double(count)) * 1_000

        let stored = try repo.fetchAll(limit: nil).count
        #expect(stored == count)
        #expect(elapsed < 30, "1k inserts took \(elapsed)s, ~\(perInsertMs)ms per insert")
    }

    @Test func fetchAllOverCappedRepositoryIsFast() throws {
        let container = try VeerStore.inMemory()
        let cap = 500
        let repo = ClipRepositoryLive(container: container, maxItems: cap)
        for i in 0..<(cap * 2) {
            let payload = ClipPayload(typed: [
                NSPasteboard.PasteboardType.string.rawValue: Data("warm-\(i)".utf8),
            ])
            _ = try repo.insert(payload: payload, sourceBundleId: nil)
        }

        let start = Date()
        let items = try repo.fetchAll(limit: nil)
        let elapsed = Date().timeIntervalSince(start)
        #expect(items.count == cap)
        #expect(elapsed < 1.0, "fetchAll over capped repo took \(elapsed)s")
    }
}
