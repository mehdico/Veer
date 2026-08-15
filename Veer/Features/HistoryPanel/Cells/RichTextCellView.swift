import AppKit
import SwiftUI

struct RichTextCellView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    let blobProvider: () -> Data?
    /// Search highlight ranges for the plain-text fallback only (attributed
    /// RTF has its own character layout, so it is left unhighlighted).
    var highlightRanges: [Range<String.Index>] = []

    @State private var attributed: AttributedString?

    private static let cache = NSCache<NSString, NSAttributedString>()

    var body: some View {
        CellChrome(isSelected: isSelected, identifier: AccessibilityIdentifiers.yippyRichTextCellView) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "doc.richtext")
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 2) {
                    if let attributed {
                        Text(attributed)
                            .lineLimit(3)
                    } else {
                        previewText
                            .lineLimit(3)
                    }
                    metadataLine
                }
                Spacer(minLength: 0)
            }
        }
        .task(id: snapshot.id) { loadAttributed() }
    }

    private var previewText: Text {
        let text = snapshot.preview ?? ""
        guard !highlightRanges.isEmpty else { return Text(text) }
        return Text(AttributedString.highlighted(text, ranges: highlightRanges))
    }

    private var metadataLine: some View {
        HStack(spacing: 6) {
            if let bundle = snapshot.sourceBundleId {
                Text(bundle)
            }
            Text(snapshot.relativeTimeLabel)
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
    }

    private func loadAttributed() {
        let key = snapshot.id.uuidString as NSString
        if let cached = Self.cache.object(forKey: key) {
            attributed = AttributedString(cached)
            return
        }
        guard let data = blobProvider(),
              let ns = try? NSAttributedString(
                  data: data,
                  options: [.documentType: NSAttributedString.DocumentType.rtf],
                  documentAttributes: nil
              )
        else { return }
        Self.cache.setObject(ns, forKey: key)
        attributed = AttributedString(ns)
    }
}
