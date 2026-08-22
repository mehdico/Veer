import Foundation

/// A mutation broadcast to `changes` subscribers, so consumers can apply deltas
/// instead of re-fetching the whole history on every change.
enum RepositoryChange: Sendable, Equatable {
    case inserted(UUID)
    case movedToFront(UUID)
    case deleted(UUID)
    case cleared
    case capped
    case pinned(UUID)
}

@MainActor
protocol ClipRepository: AnyObject {
    var maxItems: Int { get }
    func insert(
        payload: ClipPayload,
        sourceBundleId: String?,
        thumbnailPNG: Data?,
        payloadDigest: Data?,
        preview: String?,
        createdAt: Date?
    ) throws -> InsertOutcome
    func fetchAll(limit: Int?) throws -> [ClipItem]
    func fetchOne(id: UUID) throws -> ClipItem?
    func fetchSnapshots(limit: Int?) throws -> [ClipItemSnapshot]
    func fetchBlob(id: UUID, type: String) throws -> Data?
    func fetchBlobs(id: UUID) throws -> [PayloadBlob]
    func fetchThumbnail(id: UUID) throws -> Data?
    func moveToFront(id: UUID) throws
    func setPinned(id: UUID, pinned: Bool) throws
    func delete(id: UUID) throws
    func clear() throws
    func setMaxItems(_ n: Int) throws
    var changes: AsyncStream<RepositoryChange> { get }
}

extension ClipRepository {
    func insert(payload: ClipPayload, sourceBundleId: String?) throws -> InsertOutcome {
        try insert(payload: payload, sourceBundleId: sourceBundleId, thumbnailPNG: nil, payloadDigest: nil, preview: nil, createdAt: nil)
    }

    func insert(payload: ClipPayload, sourceBundleId: String?, thumbnailPNG: Data?) throws -> InsertOutcome {
        try insert(payload: payload, sourceBundleId: sourceBundleId, thumbnailPNG: thumbnailPNG, payloadDigest: nil, preview: nil, createdAt: nil)
    }

    func insert(
        payload: ClipPayload,
        sourceBundleId: String?,
        thumbnailPNG: Data?,
        payloadDigest: Data?
    ) throws -> InsertOutcome {
        try insert(payload: payload, sourceBundleId: sourceBundleId, thumbnailPNG: thumbnailPNG, payloadDigest: payloadDigest, preview: nil, createdAt: nil)
    }

    func insert(
        payload: ClipPayload,
        sourceBundleId: String?,
        thumbnailPNG: Data?,
        payloadDigest: Data?,
        preview: String?
    ) throws -> InsertOutcome {
        try insert(payload: payload, sourceBundleId: sourceBundleId, thumbnailPNG: thumbnailPNG, payloadDigest: payloadDigest, preview: preview, createdAt: nil)
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

// MARK: - JSON export / import

/// A clip serialized for export, with each payload blob base64-encoded so the
/// whole history round-trips through a single JSON file.
struct ExportedClip: Codable {
    let id: String
    let createdAt: Date
    let sourceBundleId: String?
    let typeRawValues: [String]
    let preview: String?
    let blobs: [ExportedBlob]
}

struct ExportedBlob: Codable {
    let type: String
    let dataBase64: String
}

/// Round-trips the full history to and from JSON for backup or transfer
/// between machines.
@MainActor
enum HistoryImportExport {
    /// Serializes every clip (including images, PDFs and files) in the store.
    /// Returns `nil` when the history is empty or the repository cannot be read.
    static func exportJSON(from repository: ClipRepository) -> Data? {
        guard let items = try? repository.fetchAll(limit: nil), !items.isEmpty else { return nil }
        let exported = items.map { item in
            ExportedClip(
                id: item.id.uuidString,
                createdAt: item.createdAt,
                sourceBundleId: item.sourceBundleId,
                typeRawValues: item.typeRawValues,
                preview: item.preview,
                blobs: item.blobs.map {
                    ExportedBlob(type: $0.typeRawValue, dataBase64: $0.data.base64EncodedString())
                }
            )
        }
        return try? JSONEncoder().encode(exported)
    }

    /// Inserts every clip from `data` into the store. Re-importing is
    /// best-effort: empty or duplicate clips are skipped by the repository.
    /// Returns the number of clips that were actually inserted.
    static func importJSON(_ data: Data, into repository: ClipRepository) throws -> Int {
        let decoded = try JSONDecoder().decode([ExportedClip].self, from: data)
        var imported = 0
        for clip in decoded {
            var typed: [String: Data] = [:]
            for blob in clip.blobs where !blob.dataBase64.isEmpty {
                if let blobData = Data(base64Encoded: blob.dataBase64) {
                    typed[blob.type] = blobData
                }
            }
            guard !typed.isEmpty else { continue }
            let payload = ClipPayload(typed: typed)
            let preview = clip.preview ?? payload.plainTextPreview()
            if let outcome = try? repository.insert(
                payload: payload,
                sourceBundleId: clip.sourceBundleId,
                thumbnailPNG: nil,
                payloadDigest: nil,
                preview: preview,
                createdAt: clip.createdAt
            ), case .inserted = outcome {
                imported += 1
            }
        }
        return imported
    }
}
