import Foundation

@MainActor
final class PasteboardMonitor: PasteboardMonitoring {
    private let source: PasteboardSource
    private let frontmost: FrontmostAppProviding
    private let interval: Duration
    private let continuation: AsyncStream<MonitorEvent>.Continuation
    let events: AsyncStream<MonitorEvent>
    private let logger = VeerLogger(category: .pasteboard)

    private var lastChangeCount: Int
    private var emptyRetries: Int = 0
    private var pendingChangeCount: Int?
    private var pendingStart: ContinuousClock.Instant?
    private static let maxPendingWait: Duration = .seconds(1)
    private var pollTask: Task<Void, Never>?

    init(source: PasteboardSource, frontmost: FrontmostAppProviding, interval: Duration = .milliseconds(50)) {
        self.source = source
        self.frontmost = frontmost
        self.interval = interval
        var continuation: AsyncStream<MonitorEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.continuation = continuation
        self.lastChangeCount = source.changeCount
    }

    deinit {
        continuation.finish()
    }

    func start() {
        stop()
        pollTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: self.interval)
                self.poll()
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func poll() {
        let count = source.changeCount
        guard count != lastChangeCount else { return }
        if pendingChangeCount != count {
            pendingChangeCount = count
            pendingStart = ContinuousClock().now
            emptyRetries = 0
        }
        let snapshots = source.snapshot()
        let nonEmpty = snapshots.filter { !$0.typed.isEmpty }
        if nonEmpty.isEmpty {
            let isTimedOut: Bool
            if let pendingStart {
                let now = ContinuousClock().now
                isTimedOut = pendingStart.duration(to: now) >= Self.maxPendingWait
            } else {
                isTimedOut = false
            }
            logger.info("poll: changeCount \(self.lastChangeCount)→\(count) but snapshot empty (items=\(snapshots.count), retry=\(self.emptyRetries), timeout=\(isTimedOut))")
            emptyRetries += 1
            if isTimedOut {
                lastChangeCount = count
                pendingChangeCount = nil
                pendingStart = nil
                emptyRetries = 0
            }
            return
        }
        lastChangeCount = count
        emptyRetries = 0
        pendingChangeCount = nil
        pendingStart = nil
        let bundle = frontmost.currentBundleId()
        for snapshot in nonEmpty {
            let typeList = snapshot.typed.keys.sorted().joined(separator: ",")
            let totalBytes = snapshot.typed.values.reduce(0) { $0 + $1.count }
            logger.info("yield: changeCount=\(count) bundle=\(bundle ?? "nil") types=[\(typeList)] bytes=\(totalBytes)")
            continuation.yield(MonitorEvent(
                payload: ClipPayload(typed: snapshot.typed),
                sourceBundleId: bundle
            ))
        }
    }

    func acknowledge(changeCount: Int) {
        lastChangeCount = max(lastChangeCount, changeCount)
        emptyRetries = 0
        if pendingChangeCount == changeCount {
            pendingChangeCount = nil
            pendingStart = nil
        }
    }
}
