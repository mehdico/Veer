import Foundation
import SwiftData

@MainActor
final class ClipRepositoryLive: ClipRepository {
    private let container: ModelContainer
    private let context: ModelContext
    private(set) var maxItems: Int
    private var changeContinuations: [UUID: AsyncStream<RepositoryChange>.Continuation] = [:]
    var changes: AsyncStream<RepositoryChange> {
        AsyncStream { continuation in
            let id = UUID()
            changeContinuations[id] = continuation
            continuation.onTermination = { @Sendable [id] _ in
                Task { @MainActor [weak self] in
                    self?.changeContinuations.removeValue(forKey: id)
                }
            }
        }
    }
    private let logger = VeerLogger(category: .repository)

    init(container: ModelContainer, maxItems: Int) {
        self.container = container
        self.context = ModelContext(container)
        self.maxItems = maxItems
    }

    convenience init(container: ModelContainer) {
        self.init(container: container, maxItems: Constants.History.defaultMax)
    }

    deinit {
        for (_, c) in changeContinuations { c.finish() }
        changeContinuations.removeAll()
    }

    func insert(
        payload: ClipPayload,
        sourceBundleId: String?,
        thumbnailPNG: Data?,
        payloadDigest: Data?,
        preview: String? = nil,
        createdAt: Date? = nil
    ) throws -> InsertOutcome {
        if payload.isEmpty {
            logger.info("insert rejected: empty payload (bundle=\(sourceBundleId ?? "nil"))")
            return .rejectedEmpty
        }
        if payload.hasDenyListedType {
            logger.info("insert rejected: denylisted type (bundle=\(sourceBundleId ?? "nil"))")
            return .rejectedDenyListed
        }

        let preview = preview ?? payload.plainTextPreview()
        let digest = payloadDigest ?? payload.digest()
        if let mostRecent = try fetchMostRecent(), mostRecent.payloadDigest == digest {
            logger.info("insert rejected: duplicate of most recent (preview=\(preview ?? "<binary>"))")
            return .rejectedDuplicate
        }

        let item = ClipItem(
            createdAt: createdAt ?? Date(),
            sourceBundleId: sourceBundleId,
            typeRawValues: payload.typed.keys.sorted(),
            preview: preview,
            thumbnailPNG: thumbnailPNG,
            payloadDigest: digest
        )
        for (type, data) in payload.typed {
            item.blobs.append(PayloadBlob(typeRawValue: type, data: data))
        }
        context.insert(item)
        try context.save()

        try enforceCap()
        notify(.inserted(item.id))
        return .inserted(item.id)
    }

    func fetchAll(limit: Int? = nil) throws -> [ClipItem] {
        var descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        if let limit { descriptor.fetchLimit = limit }
        return try context.fetch(descriptor)
    }

    func fetchOne(id: UUID) throws -> ClipItem? {
        var descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// List reads run on a short-lived context so the fetched rows don't stay
    /// registered in the long-lived writer context after snapshots (values)
    /// have been extracted.
    func fetchSnapshots(limit: Int?) throws -> [ClipItemSnapshot] {
        let readContext = ModelContext(container)
        var descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        if let limit { descriptor.fetchLimit = limit }
        return try readContext.fetch(descriptor).map(ClipItemSnapshot.init)
    }

    func fetchBlob(id: UUID, type: String) throws -> Data? {
        // #Predicate can't traverse the optional `item` relationship, so fetch
        // the owning item and scan its blobs. The short-lived context keeps the
        // faulted blob rows (and their payloads) out of the writer context.
        let readContext = ModelContext(container)
        var descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let item = try readContext.fetch(descriptor).first else { return nil }
        return item.blobs.first { $0.typeRawValue == type }?.data
    }

    func fetchBlobs(id: UUID) throws -> [PayloadBlob] {
        // Copies, not the fetched models: unmanaged values survive the
        // short-lived read context that loaded them.
        let readContext = ModelContext(container)
        var descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let item = try readContext.fetch(descriptor).first else { return [] }
        return item.blobs.map { PayloadBlob(typeRawValue: $0.typeRawValue, data: $0.data) }
    }

    func fetchThumbnail(id: UUID) throws -> Data? {
        var descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.thumbnailPNG
    }

    func count() throws -> Int {
        try context.fetchCount(FetchDescriptor<ClipItem>())
    }

    func moveToFront(id: UUID) throws {
        let descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.id == id })
        guard let item = try context.fetch(descriptor).first else { return }
        item.createdAt = Date()
        try context.save()
        notify(.movedToFront(id))
    }

    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.id == id })
        if let item = try context.fetch(descriptor).first {
            context.delete(item)
            try context.save()
            notify(.deleted(id))
        }
    }

    func clear() throws {
        try context.delete(model: ClipItem.self)
        try context.save()
        notify(.cleared)
    }

    func setMaxItems(_ n: Int) throws {
        let clamped = max(1, min(n, Constants.History.absoluteMax))
        maxItems = clamped
        try enforceCap()
        notify(.capped)
    }

    private func fetchMostRecent() throws -> ClipItem? {
        var descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func enforceCap() throws {
        // Count first: in the steady state (history under the cap) this is a
        // cheap indexed count instead of materializing every row on each insert.
        let total = try context.fetchCount(FetchDescriptor<ClipItem>())
        guard total > maxItems else { return }
        var descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchOffset = maxItems
        for item in try context.fetch(descriptor) {
            context.delete(item)
        }
        try context.save()
    }

    private func notify(_ change: RepositoryChange) {
        for (_, c) in changeContinuations { c.yield(change) }
    }
}
