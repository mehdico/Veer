import AppKit
import SwiftUI

struct RichTextCellView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    let blobProvider: () -> Data?

    @State private var attributed: AttributedString?

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
                        Text(snapshot.preview ?? "")
                            .lineLimit(3)
                    }
                    if let bundle = snapshot.sourceBundleId {
                        Text(bundle)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .task(id: snapshot.id) { loadAttributed() }
    }

    private func loadAttributed() {
        guard let data = blobProvider(),
              let ns = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
              )
        else { return }
        attributed = AttributedString(ns)
    }
}
