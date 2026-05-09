import Foundation
@testable import Veer

@MainActor
final class MockPasteboardSource: PasteboardSource {
    var changeCount: Int = 0
    var snapshots: [PasteboardItemSnapshot] = []
    private(set) var snapshotCallCount = 0

    func snapshot() -> [PasteboardItemSnapshot] {
        snapshotCallCount += 1
        return snapshots
    }

    func push(_ typed: [String: Data]) {
        changeCount += 1
        snapshots = [PasteboardItemSnapshot(typed: typed)]
    }
}

@MainActor
final class MockFrontmostAppProvider: FrontmostAppProviding {
    var bundleId: String?
    func currentBundleId() -> String? { bundleId }
}
