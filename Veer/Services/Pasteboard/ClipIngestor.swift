import Foundation

@MainActor
final class ClipIngestor {
    private let monitor: any PasteboardMonitoring
    private let repository: any ClipRepository
    private let textOnlyHistory: () -> Bool
    private let logger = VeerLogger(category: .pasteboard)
    private var consumeTask: Task<Void, Never>?

    init(
        monitor: any PasteboardMonitoring,
        repository: any ClipRepository,
        textOnlyHistory: @escaping () -> Bool = { false }
    ) {
        self.monitor = monitor
        self.repository = repository
        self.textOnlyHistory = textOnlyHistory
    }

    func start() {
        let stream = monitor.events
        consumeTask?.cancel()
        consumeTask = Task { @MainActor [weak self] in
            for await event in stream {
                await self?.ingestAsync(event)
            }
        }
        monitor.start()
    }

    func stop() {
        monitor.stop()
        consumeTask?.cancel()
        consumeTask = nil
    }

    @discardableResult
    func ingest(_ event: MonitorEvent) -> InsertOutcome {
        if textOnlyHistory(), !event.payload.isTextOnly {
            logger.info("ingest rejected: non-text payload in text-only mode (bundle=\(event.sourceBundleId ?? "nil"))")
            return .rejectedNonText
        }
        return (try? repository.insert(
            payload: event.payload,
            sourceBundleId: event.sourceBundleId,
            thumbnailPNG: nil,
            payloadDigest: nil
        )) ?? .rejectedEmpty
    }

    private func ingestAsync(_ event: MonitorEvent) async {
        let payload = event.payload
        if textOnlyHistory(), !payload.isTextOnly {
            logger.info("ingest rejected: non-text payload in text-only mode (bundle=\(event.sourceBundleId ?? "nil"))")
            return
        }
        let prepared = await Task.detached(priority: .utility) {
            (payload.thumbnailPNG(), payload.digest())
        }.value
        do {
            let outcome = try repository.insert(
                payload: payload,
                sourceBundleId: event.sourceBundleId,
                thumbnailPNG: prepared.0,
                payloadDigest: prepared.1
            )
            logger.info("ingest outcome: \(String(describing: outcome)) bundle=\(event.sourceBundleId ?? "nil")")
        } catch {
            logger.error("ingest threw", error)
        }
    }
}
