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
        if has(.png) || has(.tiff) { return .image }
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
