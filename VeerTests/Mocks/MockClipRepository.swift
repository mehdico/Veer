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
        payloadDigest: Data?
    ) throws -> InsertOutcome {
        if let insertError { throw insertError }
        inserted.append((payload, sourceBundleId, thumbnailPNG))
        let outcome = nextOutcome ?? .inserted(UUID())
        for (_, c) in changeContinuations { c.yield(()) }
        return outcome
    }

    func fetchAll(limit: Int?) throws -> [ClipItem] { [] }

    func fetchOne(id: UUID) throws -> ClipItem? { nil }

    private(set) var movedToFrontIds: [UUID] = []

    func moveToFront(id: UUID) throws {
        movedToFrontIds.append(id)
        for (_, c) in changeContinuations { c.yield(()) }
    }

    func delete(id: UUID) throws {
        deletedIds.append(id)
        for (_, c) in changeContinuations { c.yield(()) }
    }

    func clear() throws {
        clearCalls += 1
        for (_, c) in changeContinuations { c.yield(()) }
    }

    func setMaxItems(_ n: Int) throws {
        maxItems = n
    }
}
