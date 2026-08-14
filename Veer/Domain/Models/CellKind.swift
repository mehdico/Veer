import AppKit
import Foundation

enum CellKind: String, Sendable, CaseIterable {
    case image
    case pdf
    case color
    case file
    case richText
    case text
}

extension ClipItemSnapshot {
    var kind: CellKind {
        if typeRawValues.contains(where: { ClipPayload.imageTypeKeys.contains($0) }) { return .image }
        if has(.pdf) { return .pdf }
        if has(.color) { return .color }
        if has(.fileURL) { return .file }
        if has(.rtf) { return .richText }
        return .text
    }

    private func has(_ type: NSPasteboard.PasteboardType) -> Bool {
        typeRawValues.contains(type.rawValue)
    }
}

extension ClipPayload {
    /// True when the payload carries only text in any format (plain, rich, HTML,
    /// RTFD, URL, …) and no file reference, image, PDF or color data.
    var isTextOnly: Bool {
        // Any file reference is ignored — files of any kind, even text files.
        if typed[NSPasteboard.PasteboardType.fileURL.rawValue] != nil { return false }
        let keys = Set(typed.keys)
        if !keys.isDisjoint(with: Self.imageTypeKeys) { return false }
        if keys.contains(NSPasteboard.PasteboardType.pdf.rawValue) { return false }
        if keys.contains(NSPasteboard.PasteboardType.color.rawValue) { return false }
        // Everything else is text in some format.
        return true
    }
}
