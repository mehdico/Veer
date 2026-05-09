import AppKit
import PDFKit
import SwiftUI

struct PdfCellView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    let blobProvider: () -> Data?

    @State private var thumbnail: NSImage?

    var body: some View {
        CellChrome(isSelected: isSelected, identifier: AccessibilityIdentifiers.yippyPdfCellView) {
            HStack(spacing: 10) {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "doc.richtext")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("PDF Document")
                        .font(.system(size: 13, weight: .medium))
                    if let bundle = snapshot.sourceBundleId {
                        Text(bundle)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .task(id: snapshot.id) { loadThumbnail() }
    }

    private func loadThumbnail() {
        guard let data = blobProvider(),
              let pdf = PDFDocument(data: data),
              let page = pdf.page(at: 0)
        else { return }
        thumbnail = page.thumbnail(of: NSSize(width: 96, height: 96), for: .mediaBox)
    }
}
