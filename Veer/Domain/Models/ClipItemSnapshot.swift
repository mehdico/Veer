import Foundation

struct ClipItemSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    let sourceBundleId: String?
    let preview: String?
    /// `preview` lowercased once at snapshot creation, so search never
    /// re-folds the corpus per keystroke.
    let foldedPreview: String?
    let typeRawValues: [String]
    /// Whether the clip is pinned to the top of history.
    let pinned: Bool

    init(
        id: UUID,
        createdAt: Date,
        sourceBundleId: String?,
        preview: String?,
        typeRawValues: [String],
        pinned: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceBundleId = sourceBundleId
        self.preview = preview
        self.foldedPreview = preview?.lowercased()
        self.typeRawValues = typeRawValues
        self.pinned = pinned
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
            typeRawValues: item.typeRawValues,
            pinned: item.pinned
        )
    }
}
