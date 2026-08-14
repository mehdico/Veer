import Foundation
import SwiftData

@MainActor
final class ClipRepositoryLive: ClipRepository {
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
        preview: String? = nil
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

    func fetchBlob(id: UUID, type: String) throws -> Data? {
        var descriptor = FetchDescriptor<PayloadBlob>(
            predicate: #Predicate { $0.typeRawValue == type && $0.item?.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.data
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
        var descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = maxItems + 1
        let items = try context.fetch(descriptor)
        guard items.count > maxItems else { return }
        for item in items.suffix(from: maxItems) {
            context.delete(item)
        }
        try context.save()
    }

    private func notify(_ change: RepositoryChange) {
        for (_, c) in changeContinuations { c.yield(change) }
    }
}
