import Foundation

struct PasteboardItemSnapshot: Sendable, Equatable {
    var typed: [String: Data]
}

struct MonitorEvent: Sendable, Equatable {
    var payload: ClipPayload
    var sourceBundleId: String?
}

@MainActor
protocol PasteboardSource: AnyObject {
    var changeCount: Int { get }
    func snapshot() -> [PasteboardItemSnapshot]
}

@MainActor
protocol FrontmostAppProviding: AnyObject {
    func currentBundleId() -> String?
}

@MainActor
protocol PasteboardMonitoring: AnyObject {
    var events: AsyncStream<MonitorEvent> { get }
    func start()
    func stop()
    func poll()
    func acknowledge(changeCount: Int)
}
