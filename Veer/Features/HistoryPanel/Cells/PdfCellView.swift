import AppKit
import PDFKit
import SwiftUI

struct PdfCellView: View {
    let snapshot: ClipItemSnapshot
    let isSelected: Bool
    /// Off → no first-page thumbnail; icon + label only.
    var previewsEnabled: Bool = true
    let blobProvider: () -> Data?

    @State private var thumbnail: NSImage?

    private static let cache = NSCache<NSString, NSImage>()

    var body: some View {
        CellChrome(isSelected: isSelected, identifier: AccessibilityIdentifiers.veerPdfCellView) {
            HStack(spacing: 10) {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "doc")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("PDF Document")
                        .font(.system(size: 13, weight: .medium))
                    metadataLine
                }
                Spacer(minLength: 0)
            }
        }
        .task(id: "\(snapshot.id.uuidString)-\(previewsEnabled)") {
            guard previewsEnabled else {
                thumbnail = nil
                return
            }
            await loadThumbnail()
        }
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

    private func loadThumbnail() async {
        let key = snapshot.id.uuidString as NSString
        if let cached = Self.cache.object(forKey: key) {
            thumbnail = cached
            return
        }
        guard let data = blobProvider() else { return }
        let decoded = await Task.detached(priority: .utility) { () -> NSImage? in
            guard let pdf = PDFDocument(data: data),
                  let page = pdf.page(at: 0)
            else { return nil }
            return page.thumbnail(of: NSSize(width: 96, height: 96), for: .mediaBox)
        }.value
        if Task.isCancelled { return }
        thumbnail = decoded
        if let decoded {
            Self.cache.setObject(decoded, forKey: key)
        }
    }
}
