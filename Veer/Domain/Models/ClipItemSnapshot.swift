import Foundation

struct ClipItemSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    let sourceBundleId: String?
    let preview: String?
    let typeRawValues: [String]
    let thumbnailPNG: Data?

    init(
        id: UUID,
        createdAt: Date,
        sourceBundleId: String?,
        preview: String?,
        typeRawValues: [String],
        thumbnailPNG: Data?
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceBundleId = sourceBundleId
        self.preview = preview
        self.typeRawValues = typeRawValues
        self.thumbnailPNG = thumbnailPNG
    }
}

extension ClipItemSnapshot {
    init(_ item: ClipItem) {
        self.init(
            id: item.id,
            createdAt: item.createdAt,
            sourceBundleId: item.sourceBundleId,
            preview: item.preview,
            typeRawValues: item.typeRawValues,
            thumbnailPNG: item.thumbnailPNG
        )
    }
}
