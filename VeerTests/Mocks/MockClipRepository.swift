import Foundation
@testable import Veer

@MainActor
final class MockClipRepository: ClipRepository {
    var maxItems: Int = 500
    private(set) var inserted: [(payload: ClipPayload, sourceBundleId: String?, thumbnailPNG: Data?)] = []
    private(set) var deletedIds: [UUID] = []
    private(set) var clearCalls: Int = 0
    var nextOutcome: InsertOutcome?
    var insertError: Error?

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

    init() {
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
        preview: String?
    ) throws -> InsertOutcome {
        if let insertError { throw insertError }
        inserted.append((payload, sourceBundleId, thumbnailPNG))
        let outcome = nextOutcome ?? .inserted(UUID())
        if case .inserted(let id) = outcome {
            for (_, c) in changeContinuations { c.yield(.inserted(id)) }
        }
        return outcome
    }

    func fetchAll(limit: Int?) throws -> [ClipItem] { [] }

    func fetchOne(id: UUID) throws -> ClipItem? { nil }

    func fetchBlob(id: UUID, type: String) throws -> Data? { nil }

    func fetchThumbnail(id: UUID) throws -> Data? { nil }

    private(set) var movedToFrontIds: [UUID] = []

    func moveToFront(id: UUID) throws {
        movedToFrontIds.append(id)
        for (_, c) in changeContinuations { c.yield(.movedToFront(id)) }
    }

    func delete(id: UUID) throws {
        deletedIds.append(id)
        for (_, c) in changeContinuations { c.yield(.deleted(id)) }
    }

    func clear() throws {
        clearCalls += 1
        for (_, c) in changeContinuations { c.yield(.cleared) }
    }

    func setMaxItems(_ n: Int) throws {
        maxItems = n
        for (_, c) in changeContinuations { c.yield(.capped) }
    }
}
