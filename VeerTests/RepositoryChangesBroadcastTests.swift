import Foundation
import SwiftData
import XCTest
@testable import Veer

@MainActor
final class RepositoryChangesBroadcastTests: XCTestCase {
    func test_liveRepositoryChangesAreBroadcastToMultipleSubscribers() async throws {
        let repo = try ClipRepositoryLive(container: VeerStore.inMemory())
        let stream1 = repo.changes
        let stream2 = repo.changes

        let e1 = expectation(description: "live subscriber 1")
        let e2 = expectation(description: "live subscriber 2")

        let t1 = Task { @MainActor in
            var it = stream1.makeAsyncIterator()
            _ = await it.next()
            e1.fulfill()
        }
        let t2 = Task { @MainActor in
            var it = stream2.makeAsyncIterator()
            _ = await it.next()
            e2.fulfill()
        }

        await Task.yield()

        _ = try repo.insert(payload: ClipPayload(typed: ["public.utf8-plain-text": Data("x".utf8)]), sourceBundleId: nil, thumbnailPNG: nil)

        await fulfillment(of: [e1, e2], timeout: 1.0)
        t1.cancel()
        t2.cancel()
    }

    func test_changesAreBroadcastToMultipleSubscribers() async throws {
        let repo = MockClipRepository()

        let stream1 = repo.changes
        let stream2 = repo.changes

        let e1 = expectation(description: "subscriber 1 got change")
        let e2 = expectation(description: "subscriber 2 got change")

        let t1 = Task { @MainActor in
            var it = stream1.makeAsyncIterator()
            _ = await it.next()
            e1.fulfill()
        }
        let t2 = Task { @MainActor in
            var it = stream2.makeAsyncIterator()
            _ = await it.next()
            e2.fulfill()
        }

        await Task.yield()

        _ = try repo.insert(payload: ClipPayload(typed: ["public.utf8-plain-text": Data("x".utf8)]), sourceBundleId: nil, thumbnailPNG: nil)

        await fulfillment(of: [e1, e2], timeout: 1.0)
        t1.cancel()
        t2.cancel()
    }
}

