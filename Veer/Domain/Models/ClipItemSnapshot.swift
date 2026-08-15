import Foundation

struct ClipItemSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    let sourceBundleId: String?
    let preview: String?
    let typeRawValues: [String]

    init(
        id: UUID,
        createdAt: Date,
        sourceBundleId: String?,
        preview: String?,
        typeRawValues: [String]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceBundleId = sourceBundleId
        self.preview = preview
        self.typeRawValues = typeRawValues
    }
}

extension ClipItemSnapshot {
    /// Compact relative age ("just now", "5m ago", …) for cell metadata lines.
    var relativeTimeLabel: String {
        RelativeTime.label(for: createdAt)
    }
}

extension ClipItemSnapshot {
    init(_ item: ClipItem) {
        self.init(
            id: item.id,
            createdAt: item.createdAt,
            sourceBundleId: item.sourceBundleId,
            preview: item.preview,
            typeRawValues: item.typeRawValues
        )
    }
}
