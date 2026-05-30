import Foundation

@MainActor
protocol ClipRepository: AnyObject {
    var maxItems: Int { get }
    func insert(
        payload: ClipPayload,
        sourceBundleId: String?,
        thumbnailPNG: Data?,
        payloadDigest: Data?
    ) throws -> InsertOutcome
    func fetchAll(limit: Int?) throws -> [ClipItem]
    func fetchOne(id: UUID) throws -> ClipItem?
    func delete(id: UUID) throws
    func clear() throws
    func setMaxItems(_ n: Int) throws
    var changes: AsyncStream<Void> { get }
}

extension ClipRepository {
    func insert(payload: ClipPayload, sourceBundleId: String?) throws -> InsertOutcome {
        try insert(payload: payload, sourceBundleId: sourceBundleId, thumbnailPNG: nil, payloadDigest: nil)
    }

    func insert(payload: ClipPayload, sourceBundleId: String?, thumbnailPNG: Data?) throws -> InsertOutcome {
        try insert(payload: payload, sourceBundleId: sourceBundleId, thumbnailPNG: thumbnailPNG, payloadDigest: nil)
    }
}

enum InsertOutcome: Equatable {
    case inserted(UUID)
    case rejectedEmpty
    case rejectedDenyListed
    case rejectedDuplicate
}
