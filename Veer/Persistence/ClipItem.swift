import Foundation
import SwiftData

@Model
final class ClipItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var sourceBundleId: String?
    var typeRawValues: [String]
    var preview: String?
    /// Keeps the clip pinned to the top of history regardless of recency.
    var pinned: Bool = false
    @Attribute(.externalStorage) var thumbnailPNG: Data?
    var payloadDigest: Data
    @Relationship(deleteRule: .cascade, inverse: \PayloadBlob.item)
    var blobs: [PayloadBlob] = []

    init(
        id: UUID = UUID(),
        createdAt: Date = .init(),
        sourceBundleId: String?,
        typeRawValues: [String],
        preview: String?,
        thumbnailPNG: Data?,
        payloadDigest: Data,
        blobs: [PayloadBlob] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceBundleId = sourceBundleId
        self.typeRawValues = typeRawValues
        self.preview = preview
        self.thumbnailPNG = thumbnailPNG
        self.payloadDigest = payloadDigest
        self.blobs = blobs
    }
}
