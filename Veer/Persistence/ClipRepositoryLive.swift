import Foundation
import SwiftData

@MainActor
final class ClipRepositoryLive: ClipRepository {
    private let context: ModelContext
    private(set) var maxItems: Int
    private var changeContinuations: [UUID: AsyncStream<Void>.Continuation] = [:]
    var changes: AsyncStream<Void> {
        AsyncStream { continuation in
            let id = UUID()
            changeContinuations[id] = continuation
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor in
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

    func insert(payload: ClipPayload, sourceBundleId: String?, thumbnailPNG: Data?) throws -> InsertOutcome {
        if payload.isEmpty {
            logger.info("insert rejected: empty payload (bundle=\(sourceBundleId ?? "nil"))")
            return .rejectedEmpty
        }
        if payload.hasDenyListedType {
            logger.info("insert rejected: denylisted type (bundle=\(sourceBundleId ?? "nil"))")
            return .rejectedDenyListed
        }

        let digest = payload.digest()
        if let mostRecent = try fetchMostRecent(), mostRecent.payloadDigest == digest {
            logger.info("insert rejected: duplicate of most recent (preview=\(payload.plainTextPreview() ?? "<binary>"))")
            return .rejectedDuplicate
        }

        let item = ClipItem(
            sourceBundleId: sourceBundleId,
            typeRawValues: payload.typed.keys.sorted(),
            preview: payload.plainTextPreview(),
            thumbnailPNG: thumbnailPNG ?? payload.thumbnailPNG(),
            payloadDigest: digest
        )
        for (type, data) in payload.typed {
            item.blobs.append(PayloadBlob(typeRawValue: type, data: data))
        }
        context.insert(item)
        try context.save()

        try enforceCap()
        notify()
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

    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.id == id })
        if let item = try context.fetch(descriptor).first {
            context.delete(item)
            try context.save()
            notify()
        }
    }

    func clear() throws {
        try context.delete(model: ClipItem.self)
        try context.save()
        notify()
    }

    func setMaxItems(_ n: Int) throws {
        let clamped = max(1, min(n, Constants.History.absoluteMax))
        maxItems = clamped
        try enforceCap()
        notify()
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

    private func notify() {
        for (_, c) in changeContinuations { c.yield(()) }
    }
}
