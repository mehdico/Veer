import Foundation

@MainActor
final class ClipIngestor {
    private let monitor: any PasteboardMonitoring
    private let repository: any ClipRepository
    private let logger = VeerLogger(category: .pasteboard)
    private var consumeTask: Task<Void, Never>?

    init(monitor: any PasteboardMonitoring, repository: any ClipRepository) {
        self.monitor = monitor
        self.repository = repository
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
        (try? repository.insert(
            payload: event.payload,
            sourceBundleId: event.sourceBundleId,
            thumbnailPNG: nil
        )) ?? .rejectedEmpty
    }

    private func ingestAsync(_ event: MonitorEvent) async {
        let payload = event.payload
        let thumb = await Task.detached(priority: .utility) {
            payload.thumbnailPNG()
        }.value
        do {
            let outcome = try repository.insert(
                payload: payload,
                sourceBundleId: event.sourceBundleId,
                thumbnailPNG: thumb
            )
            logger.info("ingest outcome: \(String(describing: outcome)) bundle=\(event.sourceBundleId ?? "nil")")
        } catch {
            logger.error("ingest threw", error)
        }
    }
}
