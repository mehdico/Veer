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
    private var pendingSourceBundleId: String?
    private var lastSnapshotAttempt: ContinuousClock.Instant?
    private let maxPendingWait: Duration
    private let maxLoadingWait: Duration
    private var pollTask: Task<Void, Never>?

    init(
        source: PasteboardSource,
        frontmost: FrontmostAppProviding,
        interval: Duration = .milliseconds(50),
        maxPendingWait: Duration = .seconds(1),
        maxLoadingWait: Duration = .seconds(5)
    ) {
        self.source = source
        self.frontmost = frontmost
        self.interval = interval
        self.maxPendingWait = maxPendingWait
        self.maxLoadingWait = maxLoadingWait
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
        poll()
        pollTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let delay = self.pendingChangeCount != nil ? Duration.milliseconds(10) : self.interval
                try? await Task.sleep(for: delay)
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
            pendingSourceBundleId = frontmost.currentBundleId()
            emptyRetries = 0
            lastSnapshotAttempt = nil
        }
        // While the writing app is still filling the pasteboard, re-reading all types
        // every 10ms re-materializes the full payload each time. Snapshot a few times
        // quickly, then back off so large copies don't hammer the main thread.
        let now = ContinuousClock().now
        if let lastAttempt = lastSnapshotAttempt,
           emptyRetries >= Constants.Pasteboard.monitorSnapshotBurst,
           lastAttempt.duration(to: now) < Self.backoff(forEmptyRetries: emptyRetries)
        {
            return
        }
        lastSnapshotAttempt = now
        let snapshots = source.snapshot()
        let nonEmpty = snapshots.filter { !$0.typed.isEmpty }
        if nonEmpty.isEmpty {
            let hasItems = !snapshots.isEmpty
            let maxWait = hasItems ? maxLoadingWait : maxPendingWait
            let isTimedOut: Bool
            if let pendingStart {
                let now = ContinuousClock().now
                isTimedOut = pendingStart.duration(to: now) >= maxWait
            } else {
                isTimedOut = false
            }
            logger.info("poll: changeCount \(self.lastChangeCount)→\(count) but snapshot empty (items=\(snapshots.count), retry=\(self.emptyRetries), timeout=\(isTimedOut))")
            emptyRetries += 1
            if isTimedOut {
                lastChangeCount = count
                pendingChangeCount = nil
                pendingStart = nil
                pendingSourceBundleId = nil
                emptyRetries = 0
            }
            return
        }
        lastChangeCount = count
        emptyRetries = 0
        pendingChangeCount = nil
        pendingStart = nil
        let bundle = pendingSourceBundleId ?? frontmost.currentBundleId()
        pendingSourceBundleId = nil
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
            pendingSourceBundleId = nil
        }
    }

    private static func backoff(forEmptyRetries retries: Int) -> Duration {
        let exponent = max(0, retries - Constants.Pasteboard.monitorSnapshotBurst)
        let milliseconds = min(
            Constants.Pasteboard.monitorSnapshotBackoffCapMilliseconds,
            Constants.Pasteboard.monitorSnapshotBackoffBaseMilliseconds << min(exponent, 4)
        )
        return .milliseconds(milliseconds)
    }
}
