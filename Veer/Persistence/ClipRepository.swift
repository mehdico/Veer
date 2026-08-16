import Foundation

/// A mutation broadcast to `changes` subscribers, so consumers can apply deltas
/// instead of re-fetching the whole history on every change.
enum RepositoryChange: Sendable, Equatable {
    case inserted(UUID)
    case movedToFront(UUID)
    case deleted(UUID)
    case cleared
    case capped
}

@MainActor
protocol ClipRepository: AnyObject {
    var maxItems: Int { get }
    func insert(
        payload: ClipPayload,
        sourceBundleId: String?,
        thumbnailPNG: Data?,
        payloadDigest: Data?,
        preview: String?
    ) throws -> InsertOutcome
    func fetchAll(limit: Int?) throws -> [ClipItem]
    func fetchOne(id: UUID) throws -> ClipItem?
    func fetchSnapshots(limit: Int?) throws -> [ClipItemSnapshot]
    func fetchBlob(id: UUID, type: String) throws -> Data?
    func fetchBlobs(id: UUID) throws -> [PayloadBlob]
    func fetchThumbnail(id: UUID) throws -> Data?
    func moveToFront(id: UUID) throws
    func delete(id: UUID) throws
    func clear() throws
    func setMaxItems(_ n: Int) throws
    var changes: AsyncStream<RepositoryChange> { get }
}

extension ClipRepository {
    func insert(payload: ClipPayload, sourceBundleId: String?) throws -> InsertOutcome {
        try insert(payload: payload, sourceBundleId: sourceBundleId, thumbnailPNG: nil, payloadDigest: nil, preview: nil)
    }

    func insert(payload: ClipPayload, sourceBundleId: String?, thumbnailPNG: Data?) throws -> InsertOutcome {
        try insert(payload: payload, sourceBundleId: sourceBundleId, thumbnailPNG: thumbnailPNG, payloadDigest: nil, preview: nil)
    }

    func insert(
        payload: ClipPayload,
        sourceBundleId: String?,
        thumbnailPNG: Data?,
        payloadDigest: Data?
    ) throws -> InsertOutcome {
        try insert(payload: payload, sourceBundleId: sourceBundleId, thumbnailPNG: thumbnailPNG, payloadDigest: payloadDigest, preview: nil)
    }

    func fetchBlob(id: UUID, type: String) throws -> Data? {
        try fetchOne(id: id)?.blobs.first { $0.typeRawValue == type }?.data
    }

    func fetchSnapshots(limit: Int?) throws -> [ClipItemSnapshot] {
        try fetchAll(limit: limit).map(ClipItemSnapshot.init)
    }

    func fetchBlobs(id: UUID) throws -> [PayloadBlob] {
        try fetchOne(id: id)?.blobs ?? []
    }

    func fetchThumbnail(id: UUID) throws -> Data? {
        try fetchOne(id: id)?.thumbnailPNG
    }
}

enum InsertOutcome: Equatable {
    case inserted(UUID)
    case rejectedEmpty
    case rejectedDenyListed
    case rejectedDuplicate
    case rejectedNonText
    case rejectedIgnoredApp
}
